{{/*
All the secrets
*/}}
{{- define "stack.helpers.secrets" -}}
{{-   $Values := .Values -}}
{{-   $secrets := dict -}}
{{-   range $volName, $volValue := .Values.secrets -}}
{{-     $originalName := $volName -}}
{{-     $volName = $volName | replace "_" "-" -}}
{{-     $volValue = default dict $volValue -}}
{{-     $external := get $volValue "external" | default false -}}
{{-     $externalName := get $volValue "name" | default $originalName | replace "_" "-" -}}
{{-     $_ := set $secrets $volName (dict "volumeKind" "Secret" "originalName" $originalName "external" $external "externalName" $externalName) -}}
{{-   end -}}
{{ $secrets | toYaml }}
{{- end -}}


{{- define "stack.secret" -}}
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: {{ .volName | quote }}
{{- if get .volValue "data" }}  
data: {{ get .volValue "data" | toYaml | nindent 2 }}
{{- end }}
{{- if get .volValue "stringData" }}  
stringData: {{ get .volValue "data" | toYaml | nindent 2 }}
{{- end -}}
{{- end -}}