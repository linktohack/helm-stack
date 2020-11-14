
{{- define "stack.helpers.configMountOptions" }}
{{-   if eq (typeOf .) "string" }}
source: {{ . }}
target: {{ printf "/%s" . }}
{{-   else }}
source: {{ .source }}
target: {{ .target | default (printf "/%s" .source) }}
{{      if .mode    -}} mode:    {{ .mode    }} {{- end }}
{{      if .subPath -}} subPath: {{ .subPath }} {{- end }}
{{-   end -}}
{{- end -}}

{{- define "stack.helpers.secretMountOptions" }}
{{-   if eq (typeOf .) "string" }}
source: {{ . }}
target: {{ printf "/run/secrets/%s" . }}
{{-   else }}
source: {{ .source }}
target: {{ .target | default (printf "/run/secrets/%s" .source) }}
{{      if .mode    -}} mode:    {{ .mode    }} {{- end }}
{{      if .subPath -}} subPath: {{ .subPath }} {{- end }}
{{-   end -}}
{{- end -}}

{{- define "stack.helpers.volumeMountOptions" }}
{{-   if eq (typeOf .) "string" }}
{{-     $tokens := splitList ":" . }}
source: {{ index $tokens 0 }}
target: {{ index $tokens 1 }}
{{-     if ge (len $tokens) 3 }}
readOnly: {{ index $tokens 2 | eq "ro" }}
{{-     end }}
{{-   else }}
{{      if .source   -}} source:   {{ .source   }} {{- end }}
{{      if .target   -}} target:   {{ .target   }} {{- end }}
{{      if .readOnly -}} readOnly: {{ .readOnly }} {{- end }}
{{      if .subPath  -}} subPath:  {{ .subPath  }} {{- end }}
{{- end }}
{{- end }}

{{- define "stack.helpers.containerList" -}}
{{-   $Values := .Values -}}
{{-   $volumes := .volumes -}}
{{-   $configs := .configs -}}
{{-   $secrets := .secrets -}}
{{-   $name := .name -}}
{{-   $containers := .containers -}}
{{- /* TODO: deduplicate template process */ -}}
{{-   $owner_kind := .owner_kind -}}
{{- /* TODO: current implementation mutate parent data */ -}}
{{-   $podVolumes := .podVolumes }}
{{- /* Iterate over containers*/ -}}
{{-   range $index, $container := $containers }}
{{-     $maybeWithContainerIndex := "" -}}
{{-     if gt $index 0 -}}
{{-       $maybeWithContainerIndex = printf "-%d" $index -}}
{{-     end -}}
{{-     $volumeMounts := list -}}
{{- /* VOLUMES */ -}}
{{-     range $volIndex, $volValue := $container.volumes -}}
{{-       $mountOptions := include "stack.helpers.volumeMountOptions" $volValue | fromYaml -}}
{{-       $volName := $mountOptions.source -}}
{{- /* Hostpath scenarios */ -}}
{{-       if hasPrefix "/" $volName -}}
{{-         $name := printf "volume%s-%d" $maybeWithContainerIndex $volIndex -}}
{{-         $meta := dict "volumeKind" "Volume" "name" $name "type" "hostPath" -}}
{{-         $volume := merge $meta $mountOptions -}}
{{-         $volumeMounts = append $volumeMounts $volume -}}
{{-         $_ := set $podVolumes $name $volume -}}
{{-       else if hasPrefix "./" $volName -}}
{{-         $src := clean (printf "%s/%s" (default "." $Values.chdir) $volName) -}}
{{-         if not (isAbs $src) -}}
{{-           fail "volume path or chidir has to be absolute." -}}
{{-         end -}}
{{-         $name := printf "volume%s-%d" $maybeWithContainerIndex $volIndex -}}
{{-         $meta := dict "volumeKind" "Volume" "name" $name "type" "hostPath" "source" $src -}}
{{-         $volume := merge $meta $mountOptions -}}
{{-         $volumeMounts = append $volumeMounts $volume -}}
{{-         $_ := set $podVolumes $name $volume -}}
{{- /* Else */ -}}
{{-       else -}}
{{-         $name := $volName | replace "_" "-" -}}
{{-         $volume := merge (dict "name" $name) $mountOptions (get $volumes $name) -}}
{{-         $volumeMounts = append $volumeMounts $volume -}}
{{-         if and (eq $owner_kind "StatefulSet") (ne $volume.type "emptyDir") (not $volume.external) (get $volume "dynamic") -}}
{{-         else -}}
{{-           $_ := set $podVolumes $name $volume -}}
{{-         end -}}
{{-       end -}}
{{-     end -}}
{{- /* CONFIG */ -}}
{{-     range $volValue := $container.configs -}}
{{-       $mountOptions := include "stack.helpers.configMountOptions" $volValue | fromYaml -}}
{{-       $name := $mountOptions.source | replace "_" "-" -}}
{{-       $volume := merge (dict "name" $name) $mountOptions (get $configs $name) -}}
{{-       $volumeMounts = append $volumeMounts $volume -}}
{{-       $_ := set $podVolumes $name $volume -}}
{{-     end -}}
{{- /* SECRET: copy of CONFIG */ -}}
{{-     range $volValue := $container.secrets -}}
{{-       $mountOptions := include "stack.helpers.secretMountOptions" $volValue | fromYaml -}}
{{-       $name := $mountOptions.source | replace "_" "-" -}}
{{-       $volume := merge (dict "name" $name) $mountOptions (get $secrets $name) -}}
{{-       $volumeMounts = append $volumeMounts $volume -}}
{{-       $_ := set $podVolumes $name $volume -}}
{{-     end -}}

{{-     $name := $container.container_name | default $container.name | default (printf "%s%s" $name $maybeWithContainerIndex) | replace "_" "-" }}
{{-     $environment := include "stack.helpers.normalizeKV" $container.environment | fromYaml }}
{{-     $_ := set $container "environment" $environment }}
{{-     $_ := set $container "volumeMounts" $volumeMounts }}
{{-     $_ := set $container "name" $name }}
  - {{ include "stack.helpers.containerSpec" $container | nindent 4 | trim }}
{{-   end -}}
{{- end -}}

{{- define "stack.helpers.containerSpec" -}}
{{- $container := . -}}

name: {{ $container.name | quote }}
image: {{ $container.image | quote }}

{{- if $container.entrypoint }}
command: {{ $container.entrypoint | include "stack.helpers.normalizeEntrypoint" | nindent 12 }}
{{- end -}}

{{- if $container.command }}
args: {{ $container.command | include "stack.helpers.normalizeCommand" | nindent 12 }}
{{- end -}}

{{- if $container.hostname }}
hostname: {{ $container.hostname | quote }}
{{- end -}}

{{- $resources := include "getPath" (list $container "deploy.resources") | fromYaml -}}
{{- if $resources }}
resources:
  requests: {{ $resources.reservations | default $resources.requests | include "schema.normalizeCPU" | nindent 10 }}
  limits: {{ $resources.limits | include "schema.normalizeCPU" | nindent 10 }}
{{- end -}}

{{- if or $container.privileged $container.cap_add $container.cap_drop }}
securityContext:
  {{- if $container.privileged }}
  privileged: {{ $container.privileged }}
  {{- end -}}
  {{- if or $container.cap_add $container.cap_drop }}
  capabilities:
    {{- if $container.cap_add }}
    add: {{ $container.cap_add | toYaml | nindent 16 }}
    {{- end -}}
    {{- if $container.cap_drop }}
    drop: {{ $container.cap_drop | toYaml | nindent 16 }}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- if $container.environment }}
env:
  {{- range $envName, $envValue := $container.environment }}
  - name: {{ $envName | quote }}
    value: {{ $envValue | quote }}
  {{- end -}}
{{- end -}}

{{- if $container.volumeMounts }}
volumeMounts:
  {{- range $mount := $container.volumeMounts -}}
  {{- $volName := $mount.name -}}
  {{- if eq $mount.volumeKind "Volume" }}
  - mountPath: {{ $mount.target | quote }}
    name: {{ $mount.name | quote }}
    {{- if $mount.subPath }}
    subPath: {{ $mount.subPath | quote }}
    {{- end -}}
    {{- if $mount.readOnly }}
    readOnly: {{ $mount.readOnly }}
    {{- end }}
  {{- end -}}
  {{- if or (eq $mount.volumeKind "ConfigMap") (eq $mount.volumeKind "Secret") }}
  - mountPath: {{ $mount.target | quote }}
    name: {{ $mount.name | quote }}
    {{- $subPath := $mount.subPath | default $mount.file -}}
    {{- if $subPath }}
    subPath: {{ $subPath | base | quote }}
    {{- end -}}
  {{- end -}}
  {{- end -}}
{{- end -}}

{{- if and $container.healthcheck ($container.healthcheck | pluck "test" | first) (not ($container.healthcheck | pluck "disabled" | first)) -}}
{{ $healthCheckCommand := include "stack.helpers.normalizeHealthCheckCommand" $container.healthcheck.test | fromYaml -}}
{{- if $healthCheckCommand }}
livenessProbe:
  exec:
    command: {{ include "stack.helpers.normalizeHealthCheckCommand" $container.healthcheck.test | nindent 16 }}
  {{- if $container.healthcheck.start_period }}
  initialDelaySeconds: {{ include "stack.helpers.normalizeDuration" $container.healthcheck.start_period }}
  {{- end -}}
  {{- if $container.healthcheck.interval }}
  periodSeconds: {{ include "stack.helpers.normalizeDuration" $container.healthcheck.interval }}
  {{- end -}}
  {{- if $container.healthcheck.timeout }}
  timeoutSeconds: {{ include "stack.helpers.normalizeDuration" $container.healthcheck.timeout }}
  {{- end -}}
  {{- if $container.healthcheck.retries }}
  failureThreshold: {{ $container.healthcheck.retries }}
  {{- end -}}
{{- end -}}
{{- end -}}

{{- if $container.imagePullPolicy }}
imagePullPolicy: {{ $container.imagePullPolicy }}
{{- end -}}

{{- end -}}
