
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
  {{- range $volName, $volValue := $container.volumeMounts -}}
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
    {{- if get $volValue "file" }}
    subPath: {{ get $volValue "file" | base | quote }}
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
