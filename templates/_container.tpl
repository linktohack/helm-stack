
{{- define "stack.helpers.configMountOptions" }}
{{-   if eq (typeOf .) "string" }}
source: {{ . }}
target: {{ printf "/%s" . }}
{{-   else }}
source: {{ .source }}
target: {{ .target | default (printf "/%s" .source) }}
{{-     if .mode }}
mode: {{ .mode }}
{{-     end }}
{{-   end -}}
{{- end -}}

{{- define "stack.helpers.secretMountOptions" }}
{{-   if eq (typeOf .) "string" }}
source: {{ . }}
target: {{ printf "/run/secrets/%s" . }}
{{-   else }}
source: {{ .source }}
target: {{ .target | default (printf "/run/secrets/%s" .source) }}
{{-     if .mode }}
mode: {{ .mode }}
{{-     end }}
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

{{- define "stack.helpers.container" -}}
{{-   $name := .name -}}
{{-   $index := .index -}}
{{-   $container := .container -}}
{{-     $maybeWithContainerIndex := "" -}}
{{-     if gt $index 0 -}}
{{-       $maybeWithContainerIndex = printf "-%d" $index -}}
{{-     end -}}
{{-     $name := $container.container_name | default $container.name | default (printf "%s%s" $name $maybeWithContainerIndex) | replace "_" "-" }}
{{-     $environment := include "stack.helpers.normalizeKV" $container.environment | fromYaml }}
{{-     $_ := set $container "environment" $environment }}
{{-     $_ := set $container "name" $name }}
{{ $container | toYaml }}
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
    subPath: {{ $mount.source | quote }}
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
