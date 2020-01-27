{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "stack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "stack.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "stack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "stack.labels" -}}
helm.sh/chart: {{ include "stack.chart" . }}
{{ include "stack.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "stack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "stack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "stack.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "stack.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Normalize k:v or k=v style. Useful for volumes and labels
*/}}
{{- define "stack.helpers.normalizeKV" -}}
{{-   $dict := dict -}}
{{-   $isList := eq (typeOf .) "[]interface {}" -}}
{{-   range $name, $value := . -}}
{{-     if $isList -}}
{{-       $list := splitList "=" $value -}}
{{-       $name = first $list -}}
{{-       $value = join "=" (rest $list) -}}
{{-     end -}}
{{-     $_ := set $dict $name $value -}}
{{-   end -}}
{{ $dict | toYaml }}
{{- end -}}


{{/*
Normalize command and entrypoint
*/}}
{{- define "stack.helpers.normalizeCommand" -}}
{{-   $command := . -}}
{{-   $isList := eq (typeOf $command) "[]interface {}" -}}
{{-   if not $isList -}}
{{-     $command = splitList " " $command -}}
{{-   end -}}
{{ $command | toYaml }}
{{- end -}}


{{/*
Normalize ports:
- port:target/UDP
- port:target
- port
*/}}
{{- define "stack.helpers.normalizePorts" -}}
{{-   $tcp := list -}}
{{-   $udp := list -}}
{{-   range . -}}
{{-     $list := splitList ":" . -}}
{{-     $port := first $list -}}
{{-     $targetPort := last $list -}}
{{-     $protocol := "TCP" -}}
{{-     if ne (len $list) 2 -}}
{{-       $targetPort = $port -}}
{{-     end -}}
{{-     $maybeTargetWithProto := splitList "/" $targetPort -}}
{{-     if eq (len $maybeTargetWithProto) 2 -}}
{{-       $targetPort = first $maybeTargetWithProto -}}
{{-       $protocol = upper (last $maybeTargetWithProto) -}}
{{-     end -}}
{{-     if eq $protocol "TCP" -}}
{{-       $tcp = append $tcp (dict "protocol" $protocol "port" $port "targetPort" $targetPort) -}}
{{-     end -}}
{{-     if eq $protocol "UDP" -}}
{{-       $udp = append $udp (dict "protocol" $protocol "port" $port "targetPort" $targetPort) -}}
{{-     end -}}
{{-   end -}}
{{ dict "tcp" $tcp "udp" $udp "all" (concat $tcp $udp) | toYaml }}
{{- end -}}