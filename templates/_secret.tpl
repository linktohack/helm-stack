
{{/* Preprocess and validate secrets */}}
{{- define "stack.helpers.secrets" -}}
{{-   $Release := .Release -}}
{{-   $secrets := dict "byKey" dict "byName" dict -}}
{{-   range $key, $options := .secrets -}}
{{-     $item := dict -}}
{{-     $options = $options | default dict -}}
{{-     if $options.external -}}
{{-       $_ := set $item "external" true -}}
{{-       if not $options.name -}}
{{-         fail (printf "Missing `name` for external secret `%s`" $key) -}}
{{-       end -}}
{{-     else -}}
{{-       if hasKey $options "data" -}}
{{-         $_ := set $item "data" ($options.data | quote) -}}
{{-       end -}}
{{-       if hasKey $options "stringData" -}}
{{-         $_ := set $item "stringData" ($options.stringData | quote) -}}
{{-       end -}}
{{-       if and $item.data $item.stringData -}}
{{-         fail (printf "Could not specify both `data` and `stringData` for secret `%s`" $key) -}}
{{-       end -}}
{{-     end -}}
{{-     $name := $options.name | default (printf "%s-secrets" $Release.Name) -}}
{{/* Assign secret by key */}}
{{-     $_ := set $item "name" $name -}}
{{-     $_ := set $secrets.byKey $key $item -}}
{{/* Update or create secret by name */}}
{{-     if not $options.external -}}
{{-       $secret := get $secrets.byName $name | default dict -}}
{{-       $_ := set $secret $key $item -}}
{{-       $_ := set $secrets.byName $name $secret -}}
{{-     end -}}
{{-   end -}}
{{ $secrets | toYaml }}
{{- end -}}

{{- define "stack.secret" }}
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: {{ .name }}
data:
  {{- range $key, $options := .items }}
  {{-   if and (not $options.external) (hasKey $options "data") }}
  {{      $key }}: {{ $options.data }}
  {{-   end }}
  {{- end }}
stringData:
  {{- range $key, $options := .items }}
  {{-   if and (not $options.external) (hasKey $options "stringData") }}
  {{      $key }}: {{ $options.stringData }}
  {{-   end }}
  {{- end }}
{{- end }}
