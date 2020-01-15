{{- define "stack.deployment" -}}
{{-   $name := .name -}}
{{-   $environments := list -}}
{{-   if .service.enviroment -}}
{{-     $isList := eq (typeOf .service.environment) "[]interface {}" -}}
{{-     range $envName, $envValue := .service.environment -}}
{{-         if $isList -}}
{{-         $list := splitList "=" $envValue -}}
{{-         $envName = first $list -}}
{{-         $envValue = join "=" (rest $list) -}}
{{-       end -}}
{{-       $environments = append $environments (list $envName $envValue) -}}
{{-     end -}}
{{-   end -}}
{{-   $service := .service -}}
{{-   $volumes := dict -}}
{{-   range $volIndex, $volName := default (list) .service.volumes -}}
{{-     $storage := "10Gi" -}}
{{-     if $service.pv -}}
{{-       $storage = default "10Gi" $service.pv.storage -}}
{{-     end -}}
{{-     $list := splitList ":" $volName -}}
{{-     if hasPrefix "/" (first $list) -}}
{{-       $_ := set $volumes (printf "%s-%d" $name $volIndex) (dict "dst" (index $list 1)) -}}
{{-     else -}}
{{-       $_ := set $volumes (first $list) (dict "dst" (index $list 1)) -}}
{{-     end -}}
{{-   end -}}
{{-   $affinities := list -}}
{{-   if .service.deploy -}}
{{-     if .service.deploy.placement -}}
{{-       range $constraint := .service.deploy.placement.constraints -}}
{{-         $op := "" -}}
{{-         $pair := list -}}
{{-         $curr := splitList "==" $constraint -}}
{{-         if eq (len $curr) 2 -}}
{{-           $op = "In" -}}
{{-           $pair = $curr -}}
{{-         end -}}
{{-         $curr := splitList "!=" $constraint -}}
{{-         if eq (len $curr) 2 -}}
{{-           $op = "NotIn" -}}
{{-           $pair = $curr -}}
{{-         end -}}
{{-         if and (not (contains "==" $constraint)) (not (contains "!=" $constraint)) (hasPrefix "node.labels" $constraint) -}}
{{-           $op = "Exists" -}}
{{-         end -}}
{{-         if or (eq $op "In") (eq $op "NotIn") -}}
{{-           $first := trim (first $pair) -}}
{{-           $last := trim (last $pair) -}}
{{-           if eq $first "node.role" -}}
{{-             $val := false -}}
{{-             if eq $op "In" -}}
{{-                $val = toString (eq $last "manager") -}}
{{-             else -}}
{{-               $val = toString (ne $last "manager") -}}
{{-             end -}}
{{-             $affinities = append $affinities (dict "key" "node-role.kubernetes.io/master" "operator" $op "values" (list $val)) -}}
{{-           end -}}
{{-           if eq $first "node.hostname" -}}
{{-             $affinities = append $affinities (dict "key" "kubernetes.io/hostname" "operator" $op "values" (list $last)) -}}
{{-           end -}}
{{-           if hasPrefix "node.labels" $first -}}
{{-             $affinities = append $affinities (dict "key" (replace "node.labels." ""  $first) "operator" $op "values" (list $last)) -}}
{{-           end -}}
{{-         end -}}
{{-         if (eq $op "Exists") -}}
{{-           if hasPrefix "node.labels" $constraint -}}
{{-             $affinities = append $affinities (dict "key" (replace "node.labels." "" $constraint) "operator" $op) -}}
{{-           end -}}
{{-         end -}}
{{-       end -}}
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
      {{- if $affinities }}
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                {{- range $affinity := $affinities }}
                - key: {{ "key" | get $affinity | quote }}
                  operator: {{ "operator" | get $affinity | quote }}
                  {{- if "values" | get $affinity }}
                  values: {{ "values" | get $affinity | toYaml | nindent 20 }}
                  {{- end -}}
                {{- end -}}
      {{- end }}
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
          {{- if $volumes }}
          volumeMounts:
            {{- range $volName, $volValue := $volumes }}
            - mountPath: {{ "dst" | get $volValue | quote }}
              name: {{ $volName | quote }}
            {{- end }}
          {{- end }}
      {{ if $volumes }}
      volumes:
        {{- range $volName, $volValue := $volumes }}
        - name: {{ $volName | quote }}
          persistentVolumeClaim:
            claimName: {{ $volName | quote }}
        {{- end -}}
      {{- end -}}
{{- end -}}

{{- define "stack.service.loadbalancer" -}}
{{-   $tcpPorts := list -}}
{{-   $udpPorts := list -}}
{{-   range .service.ports -}}
{{-     $pair := splitList ":" . -}}
{{-     $port := first $pair -}}
{{-     $targetPort := last $pair -}}
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
{{-           $labelValue = join "=" (rest $list) -}}
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
{{-       $pair := splitList ":" . -}}
{{-       $ports = append $ports (last $pair) -}}
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
{{-   $hosts := list -}}
{{-   $port := "" -}}
{{-   $backend := "http" -}}
{{-   $pathPrefixStrip := list -}}
{{-   $addPrefix := "" -}}
{{-   if .service.deploy -}}
{{-     if .service.deploy.labels -}}
{{-       $isList := eq (typeOf .service.deploy.labels) "[]interface {}" -}}
{{-       range $labelName, $labelValue := .service.deploy.labels -}}
{{-         if $isList -}}
{{-           $list := splitList "=" $labelValue -}}
{{-           $labelName = first $list -}}
{{-           $labelValue = join "=" (rest $list) -}}
{{-         end -}}
{{-         if eq $labelName "traefik.frontend.rule" -}}
{{-           $rules := splitList ";" $labelValue -}}
{{-           range $rule := $rules -}}
{{-             $pair := splitList ":" $rule -}}
{{-             if eq (first $pair) "Host" -}}
{{-               $hosts = concat $hosts (splitList "," (last $pair)) -}}
{{-             end -}}
{{-             if eq (first $pair) "PathPrefixStrip" -}}
{{-               $pathPrefixStrip = concat $pathPrefixStrip (splitList "," (last $pair)) -}}
{{-             end -}}
{{-             if eq (first $pair) "AddPrefix" -}}
{{-               $addPrefix = last $pair -}}
{{-             end -}}
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
{{- if and $hosts (ne $port "") -}}
{{- $name := .name -}}
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: {{ .name | quote }}
  annotations:
    ingress.kubernetes.io/protocol: {{ $backend }}
    {{- if or $pathPrefixStrip (ne $addPrefix "") }}
    kubernetes.io/ingress.class: traefik
    {{- end }}
    {{- if $pathPrefixStrip }}
    traefik.ingress.kubernetes.io/rule-type: PathPrefixStrip
    {{- end }}
    {{- if $addPrefix }}
    traefik.ingress.kubernetes.io/request-modifier: {{ printf "AddPrefix:%s" $addPrefix }}
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
              serviceName: {{ $name | quote }}
              servicePort: {{ printf "clusterip-%s" $port | quote }}
          {{- end -}}
    {{- end -}}
{{- end -}}
{{- end -}}

{{- define "stack.pv" -}}
{{-   $volumes := dict -}}
{{-   range $volName, $volValue := default (dict) .Values.volumes -}}
{{-     $storage := "10Gi" -}}
{{-     if not $volValue -}}
{{-       $_ := set $volumes $volName (dict "dynamic" true "storage" $storage "type" "local") -}}
{{-     else -}}
{{-       $storage = default "10Gi" $volValue.storage -}}
{{-       if not $volValue.driver_opts -}}
{{-         $_ := set $volumes $volName (dict "dynamic" true "storage" $storage "type" "local") -}}
{{-       else -}}
{{-         $type := default "local" $volValue.driver_opts.type -}}
{{-         $src := $volValue.driver_opts.device -}}
{{-         $server := "" -}}
{{-         if eq $type "nfs" -}}
{{-           $o := splitList "," (default "" $volValue.driver_opts.o) -}}
{{-           range $list := $o -}}
{{-             $pair := splitList "=" $list -}}
{{-             if eq (first $pair) "addr" -}}
{{-               $server = (last $pair) -}}
{{-             end -}}
{{-           end -}}
{{-           if and $src $server -}}
{{-             $_ := set $volumes $volName (dict "dynamic" false "storage" $storage "type" "nfs" "server" $server "src" $src) -}}
{{-           else -}}
{{-             $_ := set $volumes $volName (dict "dynamic" true "storage" $storage "type" "nfs") -}}
{{-           end -}}
{{-         else -}}
{{-           if $src -}}
{{-             $_ := set $volumes $volName (dict "dynamic" false "storage" $storage "type" "local" "src" $src) -}}
{{-           else -}}
{{-             $_ := set $volumes $volName (dict "dynamic" true "storage" $storage "type" "local") -}}
{{-           end -}}
{{-         end -}}
{{-       end -}}
{{-     end -}}
{{-   end -}}
{{-   range $name, $service := .Values.services -}}
{{-     range $volIndex, $volName := default (list) $service.volumes -}}
{{-       $storage := "10Gi" -}}
{{-       $type := "" -}}
{{-       if $service.pv -}}
{{-         $storage = default "10Gi" $service.pv.storage -}}
{{-         $type := default "local" $service.pv.storageClassName -}}
{{-       end -}}
{{-       $list := splitList ":" $volName -}}
{{-       if hasPrefix "/" (first $list) -}}
{{-         $_ := set $volumes (printf "%s-%d" $name $volIndex) (dict "dynamic" false "storage" $storage "type" $type "src" (first $list) "dst" (index $list 1)) -}}
{{-       else -}}
{{-         $volume := get $volumes (first $list) -}}
{{-         if $type -}}
{{-           $_ := set $volume "type" $type -}}
{{-         end -}}
{{-         $_ := set $volume "dst" (index $list 1) -}}
{{-         $_ := set $volumes (first $list) $volume -}}
{{-       end -}}
{{-     end -}}
{{-   end -}}
{{- $namespace := .Release.Namespace -}}
{{- range $volName, $volValue := $volumes -}}
{{- if not (get $volValue "dynamic") }}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: {{ printf "%s-%s" $namespace $volName | quote }}
spec:
  claimRef:
    namespace: {{ $namespace }}
    name: {{ $volName | quote }}
  persistentVolumeReclaimPolicy: Delete
  accessModes:
    - ReadWriteOnce
  capacity:
    storage: {{ get $volValue "storage" }}
  {{- if eq (default "local" (get $volValue "type")) "local" }}
  hostPath:
    path: {{ "src" | get $volValue | quote }}
  {{- end }}
  {{- if eq (get $volValue "type") "nfs" }}
  nfs:
    server: {{ "server" | get $volValue | quote }}
    path: {{ "src" | get $volValue | quote }}
  {{- end -}}
{{- end }}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ $volName | quote }}
spec:
  accessModes:
    - ReadWriteOnce
  {{- if get $volValue "dynamic" -}}
  {{- $type := get $volValue "type" -}}
  {{- if ne $type "local" }}
  storageClassName: {{ $type | quote }}
  {{- end -}}
  {{- else }}
  storageClassName: "manual"
  {{- end }}
  resources:
    requests:
      storage: {{ get $volValue "storage" | quote }}
{{- end -}}
{{- end -}}