{{- define "stack.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .name | quote }}
spec:
  replicas: {{ .service.replicas | default 1 }}
  selector:
    matchLabels:
      service: {{ .name | quote }}
  template:
    metadata:
      labels:
        service: {{ .name | quote }}
    spec:
      containers:
        - name: {{ .name | quote }}
          image: {{ .service.image | quote }}
          {{- if (.service.environment) }}
          env:
            {{- range $envName, $envValue := .service.environment }}
            - name: {{ $envName | quote }}
              value: {{ $envValue }}
            {{- end -}}
          {{- end }}
{{- end -}}

{{- define "stack.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ .name | quote }}
spec:
  type: ClusterIP
  {{- if (.service.ports) }}
  ports:
    {{- range .service.ports -}}
    {{- $port := splitList ":" . }}
    - name: {{ printf "port-%s" (first $port) | quote }}
      port: {{ $port | last }}
      targetPort: {{ $port | last }}
    {{- end -}}
  {{- end }}
  selector:
    service: {{ .name | quote }}
{{- end -}}

{{- define "stack.ingress" -}}
{{-   if .service.deploy -}}
{{-     if .service.deploy.labels -}}
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: {{ .name | quote }}
spec:
  rules:
{{-     $host := "" }}
{{-     $port := "" }}
{{-       range .service.deploy.labels }}
{{-         $label := splitList "=" . }}
{{-         if eq (first $label) "traefik.frontend.rule" }}
{{-           $rule := splitList ":" (last $label) }}
{{-           if eq (first $rule) "Host" }}
{{-             $host = (last $rule) }}
{{-           end }}
{{-         end }}
{{-         if eq (first $label) "traefik.port" }}
{{-           $port = (last $label) }}
{{-         end }}
{{-       end }}
{{-       if and (ne $host "") (ne $port "") }}
    - host: {{ $host | quote }}
      http:
        paths:
          - path: /
            backend:
              serviceName: {{ .name | quote }}
              servicePort: {{ printf "port-%s" $port | quote }}
{{-       end }}
{{-     end }}
{{-   end }}
{{- end }}
