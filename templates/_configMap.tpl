{{/* Preprocess and validate configs */}}
{{- define "stack.helpers.configs" -}}
{{-   $configs := dict "byKey" dict "byName" dict -}}
{{-   range $key, $options := .Values.configs -}}
{{-     $item := dict -}}
{{-     $options = $options | default dict -}}
{{-     if $options.external -}}
{{-       $_ := set $item "external" true -}}
{{-     else -}}
{{-       if hasKey $options "data" -}}
{{-         $_ := set $item "data" ($options.data | quote) -}}
{{-       end -}}
{{-     end -}}
{{-     $_ := set $item "name" $options.name -}}
{{-     $_ := set $configs.byKey $key $item -}}
{{-     $name := $options.name | default $key -}}
{{-     if not $options.external -}}
{{-       $config := get $configs.byName $name | default dict -}}
{{-       $_ := set $config $key $item -}}
{{-       $_ := set $configs.byName $name $config -}}
{{-     end -}}
{{-   end -}}
{{ $configs | toYaml }}
{{- end -}}


{{- define "stack.configMap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .name }}
data:
  {{- range $key, $options := .items }}
  {{-   if and (not $options.external) (hasKey $options "data") }}
  {{      $key }}: {{ $options.data }}
  {{-   end }}
  {{- end }}
{{- end -}}
