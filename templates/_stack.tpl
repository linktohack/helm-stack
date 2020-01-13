{{- define "stack.deployment" -}}
{{- $name := .name -}}
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
          {{- end -}}
          {{- if (.service.volumes) }}
          volumeMounts:
            {{- range $volIndex, $volName := .service.volumes -}}
            {{- $path := splitList ":" $volName }}
            - mountPath: {{ $path | last }}
              name: {{ printf "%s-%d" $name $volIndex }}
            {{- end }}
          {{- end -}}
      {{ if (.service.volumes) }}
      volumes:
        {{- range $volIndex, $volName := .service.volumes -}}
        {{- $path := splitList ":" $volName }}
        - name: {{ printf "%s-%d" $name $volIndex }}
          persistentVolumeClaim:
            claimName: {{ printf "%s-%d" $name $volIndex }}
        {{- end }}
      {{- end -}}
{{- end -}}

{{- define "stack.service.nodeport" -}}
{{- if (.service.ports) -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ printf "%s-nodeport" .name | quote }}
spec:
  type: NodePort
  ports:
    {{- range .service.ports -}}
    {{- $port := splitList ":" . }}
    - name: {{ printf "nodeport-%s" (first $port) | quote }}
      nodePort: {{ $port | first }}
      port: {{ $port | last }}
    {{- end }}
  selector:
    service: {{ .name | quote }}
{{- end -}}
{{- end -}}


{{- define "stack.service.clusterip" -}}
{{-   $name := .name -}}
{{-   $ports := list -}}
{{-   if .service.deploy -}}
{{-     if .service.deploy.labels -}}
{{-       $port := "" }}
{{-       range .service.deploy.labels -}}
{{-         $label := splitList "=" . -}}
{{-         if eq (first $label) "traefik.port" -}}
{{-           $port = (last $label) -}}
{{-         end -}}
{{-       end -}}
{{-       if and (ne $port "") -}}
{{-         $ports = append $ports $port -}}
{{-       end -}}
{{-     end -}}
{{-   end -}}
{{-   if (.service.clusterip) -}}
{{-     range .service.clusterip.ports -}}
{{-       $port := splitList ":" . -}}
{{-       $ports = append $ports (last $port) -}}
{{-     end -}}
{{-   end -}}
{{- if $ports -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ printf "%s" .name | quote }}
spec:
  type: ClusterIP
  ports:
    {{- range $ports }}
    - name: {{ printf "clusterip-%s" . | quote }}
      port: {{ . }}
      targetPort: {{ . }}
    {{- end }}
  selector:
    service: {{ $name | quote }}
{{- end -}}
{{- end -}}


{{- define "stack.ingress" -}}
{{-   $host := "" -}}
{{-   $port := "" -}}
{{-   if .service.deploy -}}
{{-     if .service.deploy.labels -}}
{{-       range .service.deploy.labels -}}
{{-         $label := splitList "=" . -}}
{{-         if eq (first $label) "traefik.frontend.rule" -}}
{{-           $rule := splitList ":" (last $label) -}}
{{-           if eq (first $rule) "Host" -}}
{{-             $host = (last $rule) -}}
{{-           end -}}
{{-         end -}}
{{-         if eq (first $label) "traefik.port" -}}
{{-           $port = (last $label) -}}
{{-         end -}}
{{-       end -}}
{{-     end -}}
{{-   end -}}
{{- if and (ne $host "") (ne $port "") -}}
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: {{ .name | quote }}
spec:
  rules:
    - host: {{ $host | quote }}
      http:
        paths:
          - path: /
            backend:
              serviceName: {{ .name | quote }}
              servicePort: {{ printf "clusterip-%s" $port | quote }}
{{- end -}}
{{- end -}}

{{- define "stack.pv" -}}
{{- $namespace := .Release.Namespace -}}
{{- $name := .name -}}
{{- range $volIndex, $volName := .service.volumes -}}
{{- $path := splitList ":" $volName }}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: {{ printf "%s-%s-%d" $namespace $name $volIndex | quote }}
spec:
  claimRef:
    namespace: {{ $namespace }}
    name: {{ printf "%s-%d" $name $volIndex | quote }}
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
{{ range $volIndex, $volName := .service.volumes }}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ printf "%s-%d" $name $volIndex | quote }}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi  
{{- end -}}
{{- end -}}
