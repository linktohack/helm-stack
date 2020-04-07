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
{{-     $file := get $volValue "file" -}}
{{-     $secret := (dict "volumeKind" "Secret" "file" $file "originalName" $originalName "external" $external "externalName" $externalName) -}}
{{-     if hasKey $volValue "data" -}}
{{-       $_ := set $secret "data" (get $volValue "data") -}}
{{-     end -}}
{{-     if hasKey $volValue "stringData" -}}
{{-       $_ := set $secret "stringData" (get $volValue "stringData") -}}
{{-     end -}}
{{-     $_ := set $secrets $volName $secret -}}
{{-   end -}}
{{ $secrets | toYaml }}
{{- end -}}


{{- define "stack.secret" -}}
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: {{ .volName | quote }}
{{- if get .volValue "file" -}}
{{- if hasKey .volValue "data" }}  
data:
  {{ get .volValue "file" | base }}: {{ get .volValue "data" | quote }}
{{- else }}  
stringData:
  {{ get .volValue "file" | base }}: {{ get .volValue "stringData" | quote }}
{{- end -}}
{{- end -}}
{{- end -}}
