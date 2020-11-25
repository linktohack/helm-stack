{{/* Preprocess and validate configs */}}
{{- define "stack.helpers.configs" -}}
{{-   $Release := .Release -}}
{{-   $configs := dict "byKey" dict "byName" dict -}}
{{-   range $key, $options := .configs -}}
{{-     $item := dict -}}
{{-     $options = $options | default dict -}}
{{-     if $options.external -}}
{{-       $_ := set $item "external" true -}}
{{-       if not $options.name -}}
{{-         fail (printf "Missing `name` for external config `%s`" $key) -}}
{{-       end -}}
{{-     else -}}
{{-       if hasKey $options "data" -}}
{{-         $_ := set $item "data" ($options.data | quote) -}}
{{-       else -}}
{{-         fail (printf "Missing `data` for config `%s`" $key) -}}
{{-       end -}}
{{-     end -}}
{{-     $name := $options.name | default (printf "%s-configs" $Release.Name) -}}
{{-     $_ := set $item "name" $name -}}
{{-     $_ := set $configs.byKey $key $item -}}
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
  {{-   if not $options.external }}
  {{      $key }}: {{ $options.data }}
  {{-   end }}
  {{- end }}
{{- end -}}
