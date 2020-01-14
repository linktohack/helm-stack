{{- define "stack.deployment" -}}
{{-   $name := .name -}}
{{-   $environments := list -}}
{{-   if .service.enviroment -}}
{{-     $isList := eq (typeOf .service.environment) "[]interface {}" -}}
{{-     range $envName, $envValue := .service.environment -}}
{{-         if $isList -}}
{{-         $list := splitList "=" $envValue -}}
{{-         $envName = first $list -}}
{{-         $envValue = join "=" (last $list) -}}
{{-       end -}}
{{-       $environments = append $environments (list $envName $envValue) -}}
{{-     end -}}
{{-   end -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .name | quote }}
spec:
  replicas: {{ if .service.deploy -}} {{- .service.deploy.replicas | default 1 -}} {{- else -}} 1 {{- end }}
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
          {{- if or .service.privileged .service.cap_add .service.cap_drop }}
          securityContext:
            {{- if .service.privileged }}
            privileged: {{ .service.privileged }}
            {{- end }}
            {{- if or .service.cap_add .service.cap_drop }}
            capabilities:
              {{- if .service.cap_add }}
              add: {{ .service.cap_add | toYaml | nindent 16 }}
              {{- end }}
              {{- if .service.cap_drop }}
              drop: {{ .service.cap_drop | toYaml | nindent 16 }}
              {{- end }}
            {{- end }}
          {{- end -}}
          {{- if $environments }}
          env:
            {{- range $environments }}
            - name: {{ . | first | quote }}
              value: {{ . | last | quote }}
            {{- end -}}
          {{- end -}}
          {{- if .service.volumes }}
          volumeMounts:
            {{- range $volIndex, $volName := .service.volumes -}}
            {{- $path := splitList ":" $volName }}
            - mountPath: {{ $path | last }}
              name: {{ printf "%s-%d" $name $volIndex }}
            {{- end }}
          {{- end -}}
      {{ if .service.volumes }}
      volumes:
        {{- range $volIndex, $volName := .service.volumes -}}
        {{- $path := splitList ":" $volName }}
        - name: {{ printf "%s-%d" $name $volIndex }}
          persistentVolumeClaim:
            claimName: {{ printf "%s-%d" $name $volIndex }}
        {{- end }}
      {{- end -}}
{{- end -}}

{{- define "stack.service.loadbalancer" -}}
{{-   $tcpPorts := list -}}
{{-   $udpPorts := list -}}
{{-   range .service.ports -}}
{{-     $portDef := splitList ":" . -}}
{{-     $port := first $portDef -}}
{{-     $targetPort := last $portDef -}}
{{-     $maybeTargetWithProto := splitList "/" $targetPort -}}
{{-     $protocol := "TCP" -}}
{{-     if eq (len $maybeTargetWithProto) 2 -}}
{{-       $targetPort = first $maybeTargetWithProto -}}
{{-       $protocol = upper (last $maybeTargetWithProto) -}}
{{-     end -}}
{{-     if eq $protocol "TCP" -}}
{{-       $tcpPorts = append $tcpPorts (list $protocol $port $targetPort) -}}
{{-     end -}}
{{-     if eq $protocol "UDP" -}}
{{-       $udpPorts = append $udpPorts (list $protocol $port $targetPort) -}}
{{-     end -}}
{{-   end -}}
{{- if $tcpPorts }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ printf "%s-loadbalancer-tcp" .name | quote }}
spec:
  type: LoadBalancer
  ports:
    {{- range $tcpPorts }}
    - name: {{ printf "loadbalancer-%s-%s" (index . 1) (index . 0) | lower | quote }}
      protocol: {{ index . 0 | quote }}
      port: {{ index . 1 }}
      targetPort: {{ index . 2 }}
    {{- end }}
  selector:
    service: {{ .name | quote }}
{{- end -}}
{{- if $udpPorts }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ printf "%s-loadbalancer-udp" .name | quote }}
spec:
  type: LoadBalancer
  ports:
    {{- range $udpPorts }}
    - name: {{ printf "loadbalancer-%s-%s" (index . 1) (index . 0) | lower | quote }}
      protocol: {{ index . 0 | quote }}
      port: {{ index . 1 }}
      targetPort: {{ index . 2 }}
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
{{-       $port := "" -}}
{{-       $isList := eq (typeOf .service.deploy.labels) "[]interface {}" -}}
{{-       range $labelName, $labelValue := .service.deploy.labels -}}
{{-         if $isList -}}
{{-           $list := splitList "=" $labelValue -}}
{{-           $labelName = first $list -}}
{{-           $labelValue = join "=" (last $list) -}}
{{-         end -}}
{{-         if eq $labelName "traefik.port" -}}
{{-           $port = $labelValue -}}
{{-         end -}}
{{-       end -}}
{{-       if and (ne $port "") -}}
{{-         $ports = append $ports $port -}}
{{-       end -}}
{{-     end -}}
{{-   end -}}
{{-   if .service.clusterip -}}
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
{{-   $backend := "http" -}}
{{-   if .service.deploy -}}
{{-     if .service.deploy.labels -}}
{{-       $isList := eq (typeOf .service.deploy.labels) "[]interface {}" -}}
{{-       range $labelName, $labelValue := .service.deploy.labels -}}
{{-         if $isList -}}
{{-           $list := splitList "=" $labelValue -}}
{{-           $labelName = first $list -}}
{{-           $labelValue = join "=" (last $list) -}}
{{-         end -}}
{{-         if eq $labelName "traefik.frontend.rule" -}}
{{-           $rule := splitList ":" $labelValue -}}
{{-           if eq (first $rule) "Host" -}}
{{-             $host = (last $rule) -}}
{{-           end -}}
{{-         end -}}
{{-         if eq $labelName "traefik.port" -}}
{{-           $port = $labelValue -}}
{{-         end -}}
{{-         if eq $labelName "traefik.backend" -}}
{{-           $backend = $labelValue -}}
{{-         end -}}
{{-       end -}}
{{-     end -}}
{{-   end -}}
{{- if and (ne $host "") (ne $port "") -}}
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: {{ .name | quote }}
  annotations:
    ingress.kubernetes.io/protocol: {{ $backend }}
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
{{- $pv := .service.pv -}}
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
    storage: {{ if $pv -}} {{- $pv.storage | default "10Gi" -}} {{- else -}} 10Gi {{- end }}
  hostPath:
    path: {{ $path | first | quote }}
{{- end -}}
{{- end -}}

{{- define "stack.pvc" -}}
{{- $name := .name -}}
{{- $pv := .service.pv -}}
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
      storage: {{ if $pv -}} {{- $pv.storage | default "10Gi" -}} {{- else -}} 10Gi {{- end }}
{{- end -}}
{{- end -}}
