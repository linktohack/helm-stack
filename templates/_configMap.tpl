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
{{-     $file := get $volValue "file" -}}
{{-     $config := (dict "volumeKind" "ConfigMap" "file" $file "originalName" $originalName "external" $external "externalName" $externalName) -}}
{{-     if hasKey $volValue "data" -}}
{{-       $_ := set $config "data" (get $volValue "data") -}}
{{-     end -}}
{{-     $_ := set $configs $volName $config -}}
{{-   end -}}
{{ $configs | toYaml }}
{{- end -}}


{{- define "stack.configMap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .volName | quote }}
{{- if get .volValue "file" }}
data:
  {{ get .volValue "file" | base }}: {{ get .volValue "data" | quote }}
{{- end -}}
{{- end -}}
