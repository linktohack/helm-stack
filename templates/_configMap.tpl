{{/*
All the configs
*/}}
{{- define "stack.helpers.configs" -}}
{{-   $Values := .Values -}}
{{-   $configs := dict -}}
{{-   range $volName, $volValue := .Values.configs -}}
{{-     $originalName := $volName -}}
{{-     $volName = $volName | replace "_" "-" -}}
{{-     $volValue = default dict $volValue -}}
{{-     $external := get $volValue "external" | default false -}}
{{-     $externalName := get $volValue "name" | default $originalName | replace "_" "-" -}}
{{-     $_ := set $configs $volName (dict "volumeKind" "ConfigMap" "originalName" $originalName "external" $external "externalName" $externalName) -}}
{{-   end -}}
{{ $configs | toYaml }}
{{- end -}}


{{- define "stack.configMap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .volName | quote }}
{{- if get .volValue "data" }}  
data: {{ get .volValue "data" | toYaml | nindent 2 }}
{{- end -}}
{{- end -}}
