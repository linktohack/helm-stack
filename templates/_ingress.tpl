{{/*
All the ingresses
*/}}
{{- define "stack.helpers.ingresses" -}}
{{-   $name := .name -}}
{{-   $service := .service -}}
{{-   $ingresses := dict -}}
{{-   $h1 := dict "src" "traefik.frontend.headers.customRequestHeaders" "dst" "ingress.kubernetes.io/custom-request-headers" "val" "" -}}
{{-   $h2 := dict "src" "traefik.frontend.headers.customResponseHeaders" "dst" "ingress.kubernetes.io/custom-response-headers" "val" "" -}}
{{-   $h3 := dict "src" "traefik.frontend.headers.SSLRedirect" "dst" "ingress.kubernetes.io/ssl-redirect" "val" "" -}}
{{-   $h4 := dict "src" "traefik.frontend.redirect.entryPoint" "dst" "traefik.ingress.kubernetes.io/redirect-entry-point" "val" "" -}}
{{-   $customHeadersDef := list $h1 $h2 $h3 $h4 -}}
{{-   $labels := $service | pluck "deploy" | first | default dict | pluck "labels" | first | default list -}}
{{-   $segments := list -}}
{{-   range $labelName, $labelValue := include "stack.helpers.normalizeKV" $labels | fromYaml -}}
{{-     $match := regexFind "^traefik\\.(\\w+\\.)?frontend\\.rule$" $labelName -}}
{{-     if $match -}}
{{-       $segment := "" -}}
{{-       $list := $match | splitList "." -}}
{{-       if eq (len $list) 4 -}}
{{-         $segment = index $list 1 -}}
{{-       end -}}
{{-       $segments = append $segments $segment -}}
{{-     end -}}
{{-   end -}}
{{-   range $segment := $segments -}}
{{-     $hosts := list -}}
{{-     $port := "" -}}
{{-     $backend := "http" -}}
{{-     $auth := "" -}}
{{-     $pathPrefixStrip := list -}}
{{-     $addPrefix := "" -}}
{{-     $customHeaders := list -}}
{{-     $segmentPrefix := "traefik" -}}
{{-     if ($segment) -}}
{{-       $segmentPrefix = printf "traefik.%s" $segment -}}
{{-     end -}}
{{-     range $labelName, $labelValue := include "stack.helpers.normalizeKV" $labels | fromYaml -}}
{{-       if eq $labelName (regexReplaceAllLiteral "^traefik" "traefik.frontend.rule" $segmentPrefix) -}}
{{-         $rules := splitList ";" $labelValue -}}
{{-         range $rule := $rules -}}
{{-           $pair := splitList ":" $rule -}}
{{-           if eq (first $pair) "Host" -}}
{{-             $hosts = concat $hosts (splitList "," (last $pair)) -}}
{{-           end -}}
{{-           if eq (first $pair) "PathPrefixStrip" -}}
{{-             $pathPrefixStrip = concat $pathPrefixStrip (splitList "," (last $pair)) -}}
{{-           end -}}
{{-           if eq (first $pair) "AddPrefix" -}}
{{-             $addPrefix = last $pair -}}
{{-           end -}}
{{-         end -}}
{{-       end -}}
{{-       if eq $labelName (regexReplaceAllLiteral "^traefik" "traefik.port" $segmentPrefix) -}}
{{-         $port = $labelValue -}}
{{-       end -}}
{{-       if eq $labelName (regexReplaceAllLiteral "^traefik" "traefik.backend" $segmentPrefix) -}}
{{-         $backend = $labelValue -}}
{{-       end -}}
{{-       if eq $labelName (regexReplaceAllLiteral "^traefik" "traefik.frontend.auth.basic" $segmentPrefix) -}}
{{-         $auth = $labelValue | replace "$$" "$" -}}
{{-       end -}}
{{-       if eq $labelName (regexReplaceAllLiteral "^traefik" "traefik.frontend.auth.basic.users" $segmentPrefix) -}}
{{-         $auth = $labelValue | replace "$$" "$" -}}
{{-       end -}}
{{-       range $header := $customHeadersDef -}}
{{-         if eq $labelName (regexReplaceAllLiteral "^traefik" (get $header "src") $segmentPrefix) -}}
{{-           $header := $header | deepCopy | merge (dict "val" $labelValue) -}}
{{-           $customHeaders = append $customHeaders $header -}}
{{-         end -}}
{{-       end -}}
{{-     end -}}
{{-     $_ := set $ingresses (default "default" $segment) (dict "hosts" $hosts "port" $port "backend" $backend "auth" $auth "pathPrefixStrip" $pathPrefixStrip "addPrefix" $addPrefix "customHeaders" $customHeaders) -}}
{{-   end  }}
{{ $ingresses | toYaml }}
{{- end -}}


{{- define "stack.ingress" -}}
{{-   $name := .name -}}
{{-   $segment := .segment -}}
{{-   $ingress := .ingress -}}
{{-   $hosts := $ingress.hosts -}}
{{-   $port := $ingress.port -}}
{{-   $backend := $ingress.backend -}}
{{-   $auth := $ingress.auth -}}
{{-   $pathPrefixStrip := $ingress.pathPrefixStrip -}}
{{-   $addPrefix := $ingress.addPrefix -}}
{{-   $customHeaders := $ingress.customHeaders -}}
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: {{ printf "%s-%s" $name $segment | replace "_" "-" | quote }}
  annotations:
    {{- if ne $backend "http" }}
    ingress.kubernetes.io/protocol: {{ $backend }}
    {{- end }}
    {{- if $auth }}
    ingress.kubernetes.io/auth-type: basic
    ingress.kubernetes.io/auth-realm: traefik
    ingress.kubernetes.io/auth-secret: {{ printf "%s-%s-basic-auth"  $name $segment | replace "_" "-" | quote }}
    {{- end }}
    {{- if or $pathPrefixStrip (ne $addPrefix "") $customHeaders }}
    kubernetes.io/ingress.class: traefik
    {{- end }}
    {{- if $pathPrefixStrip }}
    traefik.ingress.kubernetes.io/rule-type: PathPrefixStrip
    {{- end }}
    {{- if $addPrefix }}
    traefik.ingress.kubernetes.io/request-modifier: {{ printf "AddPrefix:%s" $addPrefix }}
    {{- end -}}
    {{- range $header := $customHeaders }}
    {{ get $header "dst" }}: {{ get $header "val" | quote }}
    {{- end }}
spec:
  rules:
    {{- range $host := $hosts }}
    - host: {{ $host | quote }}
      http:
        paths:
          {{- range $path := default (list "/") $pathPrefixStrip }}
          - path: {{ $path | quote }}
            backend:
              serviceName: {{ printf "%s" $name | quote }}
              servicePort: {{ printf "tcp-%s" $port | quote }}
          {{- end -}}
    {{- end -}}
{{- end -}}


{{- define "stack.ingress.auth" -}}
{{- $name := .name -}}
{{- $segment := .segment -}}
{{- $auth := .ingress.auth -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ printf "%s-%s-basic-auth" $name $segment | replace "_" "-" | quote }}
type: Opaque
data:
  auth: {{ $auth | b64enc }}
{{- end -}}


