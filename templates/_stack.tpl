{{- define "stack.deployment" -}}
{{ $name := .name }}
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
          {{- if (.service.volumes) }}
          volumeMounts:
          {{- range $i, $volume := .service.volumes }}
            {{- $path := splitList ":" $volume }}
            - mountPath: {{ $path | last }}
              name: {{ printf "%s-%d" $name $i }}
            {{- end }}
          {{- end -}}
      {{ if (.service.volumes) }}
      volumes:
      {{- range $i, $volume := .service.volumes }}
        {{- $path := splitList ":" $volume }}
        - name: {{ printf "%s-%d" $name $i }}
          persistentVolumeClaim:
            claimName: {{ printf "%s-%d" $name $i }}
        {{- end }}
      {{- end -}}
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
{{-       end -}}
{{-     end -}}
{{-   end -}}
{{- end -}}

{{- define "stack.pv" -}}
{{- $namespace := .Release.Namespace }}
{{- $name := .name }}
{{- range $i, $volume := .service.volumes }}
{{- $path := splitList ":" $volume }}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: {{ printf "%s-%s-%d" $namespace $name $i | quote }}
spec:
  claimRef:
    namespace: {{ $namespace }}
    name: {{ printf "%s-%d" $name $i | quote }}
  persistentVolumeReclaimPolicy: Delete
  accessModes:
    - ReadWriteOnce
  capacity:
    storage: 10Gi
  hostPath:
    path: {{ $path | first | quote }}
{{- end -}}
{{- end -}}

{{- define "stack.pvc" -}}
{{ $name := .name }}
{{ range $i, $volume := .service.volumes }}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ printf "%s-%d" $name $i | quote }}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi  
{{- end -}}
{{- end -}}
