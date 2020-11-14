
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
{{-       $list := splitList ":" $volValue -}}
{{-       $volName := first $list -}}
{{-       $mountPath := index $list 1 -}}
{{- /* Readonly mount support */ -}}
{{-       $readOnly := false -}}
{{-       if and (len $list | lt 2) -}}
{{-         if index $list 2 | eq "ro" -}}
{{-           $readOnly = true -}}
{{-         end -}}
{{-       end -}}
{{- /* Hostpath scenarios */ -}}
{{-       if hasPrefix "/" $volName -}}
{{-         $name := printf "volume%s-%d" $maybeWithContainerIndex $volIndex -}}
{{-         $volume := dict "volumeKind" "Volume" "name" $name "type" "hostPath" "src" $volName "dst" $mountPath "readOnly" $readOnly -}}
{{-         $volumeMounts = append $volumeMounts $volume -}}
{{-         $_ := set $podVolumes $name $volume -}}
{{-       else if hasPrefix "./" $volName -}}
{{-         $src := clean (printf "%s/%s" (default "." $Values.chdir) $volName) -}}
{{-         if not (isAbs $src) -}}
{{-           fail "volume path or chidir has to be absolute." -}}
{{-         end -}}
{{-         $name := printf "volume%s-%d" $maybeWithContainerIndex $volIndex -}}
{{-         $volume := dict "volumeKind" "Volume" "name" $name "type" "hostPath" "src" $src "dst" $mountPath "readOnly" $readOnly -}}
{{-         $volumeMounts = append $volumeMounts $volume -}}
{{-         $_ := set $podVolumes $name $volume -}}
{{- /* Else */ -}}
{{-       else -}}
{{-         $name := $volName | replace "_" "-" -}}
{{-         $volume := merge (dict "name" $name "dst" $mountPath "readOnly" $readOnly) (get $volumes $name) -}}
{{-         $volumeMounts = append $volumeMounts $volume -}}
{{-         if and (eq $owner_kind "StatefulSet") (ne $volume.type "emptyDir") (not $volume.external) (get $volume "dynamic") -}}
{{-         else -}}
{{-           $_ := set $podVolumes $name $volume -}}
{{-         end -}}
{{-       end -}}
{{-     end -}}
{{- /* CONFIG */ -}}
{{-     range $volValue := $container.configs -}}
{{-       if ne (typeOf $volValue) "string" -}}
{{-         $name := get $volValue "source" | replace "_" "-" -}}
{{-         $volume := merge (dict "name" $name) (get $configs $name) $volValue -}}
{{-         $volumeMounts = append $volumeMounts $volume -}}
{{-         $_ := set $podVolumes $name $volume -}}
{{-       else -}}
{{-         $name := $volValue | replace "_" "-" -}}
{{-         $volume := merge (dict "name" $name) (get $configs $name) -}}
{{-         $volumeMounts = append $volumeMounts $volume -}}
{{-         $_ := set $podVolumes $name $volume -}}
{{-       end -}}
{{-     end -}}
{{- /* SECRET: copy of CONFIG */ -}}
{{-     range $volValue := $container.secrets -}}
{{-       if ne (typeOf $volValue) "string" -}}
{{-         $name := get $volValue "source" | replace "_" "-" -}}
{{-         $volume := merge (dict "name" $name) (get $secrets $name) $volValue -}}
{{-         $volumeMounts = append $volumeMounts $volume -}}
{{-         $_ := set $podVolumes $name $volume -}}
{{-       else -}}
{{-         $name := $volValue | replace "_" "-" -}}
{{-         $volume := merge (dict "name" $name) (get $secrets $name) -}}
{{-         $volumeMounts = append $volumeMounts $volume -}}
{{-         $_ := set $podVolumes $name $volume -}}
{{-       end -}}
{{-     end -}}
{{- /* Set container.environments */ -}}
{{-     $environment := include "stack.helpers.normalizeKV" $container.environment | fromYaml }}
{{-     $_ := set $container "environment" $environment }}
{{- /* Set container.volumeMounts */ -}}
{{-     $_ := set $container "volumeMounts" $volumeMounts }}
{{- /* Set container.name */ -}}
{{-     $name := $container.container_name | default $container.name | default (printf "%s%s" $name $maybeWithContainerIndex) | replace "_" "-" }}
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
  {{- range $volValue := $container.volumeMounts -}}
  {{- $volName := $volValue.name -}}
  {{- if eq (get $volValue "volumeKind") "Volume" }}
  - mountPath: {{ get $volValue "dst" | quote }}
    name: {{ $volName | quote }}
    {{- if get $volValue "subPath" }}
    subPath: {{ get $volValue "subPath" | quote }}
    {{- end -}}
    {{- if get $volValue "readOnly" }}
    readOnly: {{ get $volValue "readOnly" }}
    {{- end }}
  {{- end -}}
  {{- if eq (get $volValue "volumeKind") "ConfigMap" }}
  - mountPath: {{ get $volValue "target" | default (printf "/%s" (get $volValue "originalName")) | quote }}
    name: {{ $volName | quote }}
    {{- if get $volValue "file" }}
    subPath: {{ get $volValue "file" | base | quote }}
    {{- end -}}
  {{- end -}}
  {{- if eq (get $volValue "volumeKind") "Secret" }}
  - mountPath: {{ get $volValue "target" | default (printf "/run/secrets/%s" (get $volValue "originalName")) | quote }}
    name: {{ $volName | quote }}
    {{- $subPath := $volValue.file | default $volValue.subPath -}}
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
