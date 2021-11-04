{{/*
All the ingresses
*/}}
{{- define "stack.helpers.ingresses" -}}
{{-   $name := .name -}}
{{-   $service := .service -}}
{{-   $ingresses := dict -}}
{{-   $h1 := dict "src" "traefik.frontend.headers.customRequestHeaders" "dst" "ingress.kubernetes.io/custom-request-headers" -}}
{{-   $h2 := dict "src" "traefik.frontend.headers.customResponseHeaders" "dst" "ingress.kubernetes.io/custom-response-headers" -}}
{{-   $h3 := dict "src" "traefik.frontend.headers.SSLRedirect" "dst" "ingress.kubernetes.io/ssl-redirect" -}}
{{-   $h4 := dict "src" "traefik.frontend.auth.basic.removeHeader" "dst" "ingress.kubernetes.io/auth-remove-header" -}}
{{-   $h5 := dict "src" "traefik.frontend.redirect.entryPoint" "dst" "traefik.ingress.kubernetes.io/redirect-entry-point" -}}
{{-   $customHeadersMap := list $h1 $h2 $h3 $h4 $h5 -}}
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
{{-     $pathPrefix := list -}}
{{-     $pathPrefixStrip := list -}}
{{-     $addPrefix := "" -}}
{{-     $ingressClass := "" -}}
{{-     $issuer := "" -}}
{{-     $clusterIssuer := "" -}}
{{-     $customHeaders := list -}}
{{-     $segmentPrefix := "traefik" -}}
{{-     if ($segment) -}}
{{-       $segmentPrefix = printf "traefik.%s" $segment -}}
{{-     end -}}
{{-     range $labelName, $labelValue := include "stack.helpers.normalizeKV" $labels | fromYaml -}}
{{-       if eq $labelName (regexReplaceAllLiteral "^traefik" "traefik.ingress-class" $segmentPrefix) -}}
{{-         $ingressClass = $labelValue -}}
{{-       end -}}
{{-       if eq $labelName (regexReplaceAllLiteral "^traefik" "traefik.frontend.rule" $segmentPrefix) -}}
{{-         $rules := splitList ";" $labelValue -}}
{{-         range $rule := $rules -}}
{{-           $pair := splitList ":" $rule -}}
{{-           if eq (first $pair) "Host" -}}
{{-             $hosts = concat $hosts (splitList "," (last $pair)) -}}
{{-           end -}}
{{-           if eq (first $pair) "PathPrefix" -}}
{{-             $pathPrefix = concat $pathPrefix (splitList "," (last $pair)) -}}
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
{{-       if eq $labelName (regexReplaceAllLiteral "^traefik" "traefik.issuer" $segmentPrefix) -}}
{{-         $issuer = $labelValue -}}
{{-       end -}}
{{-       if eq $labelName (regexReplaceAllLiteral "^traefik" "traefik.cluster-issuer" $segmentPrefix) -}}
{{-         $clusterIssuer = $labelValue -}}
{{-       end -}}
{{-       range $header := $customHeadersMap -}}
{{-         if eq $labelName (regexReplaceAllLiteral "^traefik" (get $header "src") $segmentPrefix) -}}
{{-           $header := $header | deepCopy | merge (dict "val" $labelValue) -}}
{{-           $customHeaders = append $customHeaders $header -}}
{{-         end -}}
{{-       end -}}
{{-     end -}}
{{-     $_ := set $ingresses (default "default" $segment) (dict "hosts" $hosts "port" $port "backend" $backend "auth" $auth "pathPrefix" $pathPrefix "pathPrefixStrip" $pathPrefixStrip "addPrefix" $addPrefix "ingressClass" $ingressClass "issuer" $issuer "clusterIssuer" $clusterIssuer "customHeaders" $customHeaders) -}}
{{-   end -}}
{{ $ingresses | toYaml }}
{{- end -}}


{{- define "stack.ingress" -}}
{{-   $name := .name | replace "_" "-" -}}
{{-   $segment := .segment | replace "_" "-" -}}
{{-   $ingress := .ingress -}}
{{-   $hosts := $ingress.hosts -}}
{{-   $port := $ingress.port -}}
{{-   $backend := $ingress.backend -}}
{{-   $auth := $ingress.auth -}}
{{-   $pathPrefix := $ingress.pathPrefix -}}
{{-   $pathPrefixStrip := $ingress.pathPrefixStrip -}}
{{-   $addPrefix := $ingress.addPrefix -}}
{{-   $ingressClass := $ingress.ingressClass -}}
{{-   $issuer := $ingress.issuer -}}
{{-   $clusterIssuer := $ingress.clusterIssuer -}}
{{-   $customHeaders := $ingress.customHeaders -}}
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: {{ printf "%s-%s" $name $segment | quote }}
  annotations:
    {{- if ne $backend "http" }}
    ingress.kubernetes.io/protocol: {{ $backend }}
    {{-   if regexFind "nginx" $ingressClass }}
    nginx.ingress.kubernetes.io/backend-protocol: {{ $backend }}
    {{-   end -}}
    {{- end -}}
    {{- if $auth }}
    ingress.kubernetes.io/auth-type: basic
    ingress.kubernetes.io/auth-realm: traefik
    ingress.kubernetes.io/auth-secret: {{ printf "%s-%s-basic-auth" $name $segment | quote }}
    {{-   if regexFind "nginx" $ingressClass }}
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-realm: nginx
    nginx.ingress.kubernetes.io/auth-secret: {{ printf "%s-%s-basic-auth" $name $segment | quote }}
    {{-   end -}}
    {{- end -}}
    {{- if $ingressClass }}
    kubernetes.io/ingress.class: {{ $ingressClass }}
    {{- end -}}
    {{- if $issuer }}
    cert-manager.io/issuer: {{ $issuer }}
    {{- end -}}
    {{- if $clusterIssuer }}
    cert-manager.io/cluster-issuer: {{ $clusterIssuer }}
    {{- end -}}
    {{- if $addPrefix }}
    traefik.ingress.kubernetes.io/request-modifier: {{ printf "AddPrefix:%s" $addPrefix }}
    {{- end -}}
    {{- range $header := $customHeaders }}
    {{ get $header "dst" }}: {{ get $header "val" | quote }}
    {{- end -}}
    {{- if regexFind "nginx" $ingressClass }}
    {{-   if $pathPrefix }}
    nginx.ingress.kubernetes.io/rewrite-target: {{ first $pathPrefix }}/$1
    {{-   end }}
    {{-   if $pathPrefixStrip }}
    nginx.ingress.kubernetes.io/rewrite-target: /$1
    {{-   end }}
    {{- else }}
    {{-   if $pathPrefixStrip }}
    traefik.ingress.kubernetes.io/rule-type: PathPrefixStrip
    {{-   end }}
    {{- end }}
spec:
  {{- if $ingressClass }}
  ingressClassName: {{ $ingressClass }}
  {{- end }}
  rules:
    {{- range $host := $hosts }}
    - host: {{ $host | quote }}
      http:
        paths:
          {{- range $path := $pathPrefix | default $pathPrefixStrip | default (list "/") -}}
          {{- if and (regexFind "nginx" $ingressClass) (ne $path "/") -}}
          {{-   $path = printf "%s/(.*)" $path -}}
          {{- end }}
          - path: {{ $path | quote }}
            backend:
              serviceName: {{ printf "%s" $name | quote }}
              servicePort: {{ printf "tcp-%s" $port | quote }}
          {{- end -}}
    {{- end -}}
  {{- if or $issuer $clusterIssuer }}
  tls:
    - hosts: {{ $hosts | toYaml | nindent 8 }}
      secretName: {{ printf "%s-%s-cert" $name $segment | quote }}
  {{- end -}}
{{- end -}}


{{- define "stack.ingress.auth" -}}
{{- $name := .name | replace "_" "-" -}}
{{- $segment := .segment | replace "_" "-" -}}
{{- $auth := .ingress.auth -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ printf "%s-%s-basic-auth" $name $segment | quote }}
type: Opaque
data:
  auth: {{ $auth | b64enc }}
{{- end -}}


