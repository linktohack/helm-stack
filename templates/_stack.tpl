{{- define "stack.helpers.normalizeDict" -}}
{{-   $dict := dict -}}
{{-   $isList := eq (typeOf .) "[]interface {}" -}}
{{-   range $name, $value := . -}}
{{-     if $isList -}}
{{-       $list := splitList "=" $value -}}
{{-       $name = first $list -}}
{{-       $value = join "=" (rest $list) -}}
{{-     end -}}
{{-     $_ := set $dict $name $value -}}
{{-   end -}}
{{ $dict | toYaml }}
{{- end -}}


{{- define "stack.helpers.normalizePorts" -}}
{{-   $tcp := list -}}
{{-   $udp := list -}}
{{-   range . -}}
{{-     $list := splitList ":" . -}}
{{-     $port := first $list -}}
{{-     $targetPort := last $list -}}
{{-     $protocol := "TCP" -}}
{{-     if ne (len $list) 2 -}}
{{-       $targetPort = $port -}}
{{-       $port = "" -}}
{{-     end -}}
{{-     $maybeTargetWithProto := splitList "/" $targetPort -}}
{{-     if eq (len $maybeTargetWithProto) 2 -}}
{{-       $targetPort = first $maybeTargetWithProto -}}
{{-       $protocol = upper (last $maybeTargetWithProto) -}}
{{-     end -}}
{{-     if eq $protocol "TCP" -}}
{{-       $tcp = append $tcp (dict "protocol" $protocol "port" $port "targetPort" $targetPort) -}}
{{-     end -}}
{{-     if eq $protocol "UDP" -}}
{{-       $udp = append $udp (dict "protocol" $protocol "port" $port "targetPort" $targetPort) -}}
{{-     end -}}
{{-   end -}}
{{ dict "tcp" $tcp "udp" $udp "all" (concat $tcp $udp) | toYaml }}
{{- end -}}


{{- define "stack.helpers.deploymentKind" -}}
{{-   $kind := "Deployment" -}}
{{-   $mode := pluck "deploy" . | first | default list | pluck "mode" | first | default "replicated" -}}
{{-   if eq $mode "global" -}}
{{-      $kind = "DaemonSet" -}}
{{-   end -}}
{{-   if .kind -}}
{{-     $kind = .kind -}}
{{-   end -}}
{{ $kind }}
{{- end -}}


{{- define "stack.helpers.volumes" -}}
{{-   $Values := .Values -}}
{{-   $volumes := dict -}}
{{-   range $volName, $volValue := .Values.volumes -}}
{{-     $originalName := $volName -}}
{{-     $volName = $volName | replace "_" "-" -}}
{{-     $volValue = default dict $volValue -}}
{{-     $external := pluck "external" $volValue | first | default false -}}
{{-     $externalName := pluck "name" $volValue | first | default $originalName | replace "_" "-" -}}
{{-     $dynamic := true -}}
{{-     $storage := $volValue.storage -}}
{{-     $type := "none" -}}
{{-     $src := "" -}}
{{-     $server := "" -}}
{{-     $subPath := $volValue.subPath -}}
{{-     if $volValue.driver_opts -}}
{{-       $type = default "none" $volValue.driver_opts.type -}}
{{-       $src = default "" $volValue.driver_opts.device -}}
{{-       $o := splitList "," (default "" $volValue.driver_opts.o) -}}
{{-       if hasPrefix "./" $src -}}
{{-         $src = clean (printf "%s/%s" (default "." $Values.chdir) $src) -}}
{{-         if not (isAbs $src) -}}
{{-           fail "volume path or chidir has to be absolute." -}}
{{-         end -}}
{{-       end -}}
{{-       if eq $type "none" -}}
{{-         $dynamic = not $src -}}
{{-       else if eq $type "nfs" -}}
{{-         range $list := $o -}}
{{-           $pair := splitList "=" $list -}}
{{-           if eq (first $pair) "addr" -}}
{{-             $server = (last $pair) -}}
{{-           end -}}
{{-         end -}}
{{-         $dynamic = or (not $src) (not $server) -}}
{{-       end -}}
{{-     end -}}
{{-     $_ := set $volumes $volName (dict "volumeKind" "Volume" "dynamic" $dynamic "storage" $storage "type" $type "src" $src "dst" "" "server" $server "subPath" $subPath "originalName" $originalName "external" $external "externalName" $externalName) -}}
{{-   end -}}
{{-   range $name, $service := .Values.services -}}
{{-     $kind := include "stack.helpers.deploymentKind" $service -}}
{{-     range $volIndex, $volValue := $service.volumes -}}
{{-       $list := splitList ":" $volValue -}}
{{-       $volName := first $list | replace "_" "-" -}}
{{-       if and (not (hasPrefix "/" $volName)) (not (hasPrefix "./" $volName)) -}}
{{-         $volume := get $volumes $volName -}}
{{-         $_ := set $volume "deploymentKind" $kind -}}
{{-       end -}}
{{-     end -}}
{{-   end }}
{{ $volumes | toYaml }}
{{- end -}}


{{- define "stack.helpers.configs" -}}
{{-   $Values := .Values -}}
{{-   $configs := dict -}}
{{-   range $volName, $volValue := .Values.configs -}}
{{-     $originalName := $volName -}}
{{-     $volName = $volName | replace "_" "-" -}}
{{-     $volValue = default dict $volValue -}}
{{-     $external := pluck "external" $volValue | first | default false -}}
{{-     $externalName := pluck "name" $volValue | first | default $originalName | replace "_" "-" -}}
{{-     $_ := set $configs $volName (dict "volumeKind" "ConfigMap" "originalName" $originalName "external" $external "externalName" $externalName) -}}
{{-   end -}}
{{-   range $name, $service := .Values.services -}}
{{-     range $volValue := $service.configs -}}
{{-       $volName := get $volValue "source" | replace "_" "-" -}}
{{-       $config := get $configs $volName -}}
{{-       $config = merge $config $volValue -}}
{{-       $_ := set $configs $volName $config -}}
{{-     end -}}
{{-   end }}
{{ $configs | toYaml }}
{{- end -}}


{{- define "stack.helpers.secrets" -}}
{{-   $Values := .Values -}}
{{-   $secrets := dict -}}
{{-   range $volName, $volValue := .Values.secrets -}}
{{-     $originalName := $volName -}}
{{-     $volName = $volName | replace "_" "-" -}}
{{-     $volValue = default dict $volValue -}}
{{-     $external := pluck "external" $volValue | first | default false -}}
{{-     $externalName := pluck "name" $volValue | first | default $originalName | replace "_" "-" -}}
{{-     $_ := set $secrets $volName (dict "volumeKind" "Secret" "originalName" $originalName "external" $external "externalName" $externalName) -}}
{{-   end -}}
{{-   range $name, $service := .Values.services -}}
{{-     range $volValue := $service.secrets -}}
{{-       $volName := get $volValue "source" | replace "_" "-" -}}
{{-       $secret := get $secrets $volName -}}
{{-       $secret = merge $secret $volValue -}}
{{-       $_ := set $secrets $volName $secret -}}
{{-     end -}}
{{-   end }}
{{ $secrets | toYaml }}
{{- end -}}

{{- define "stack.helpers.ingress" -}}
{{-   $name := .name -}}
{{-   $ingresses := dict -}}
{{-   $h1 := dict "src" "traefik.frontend.headers.customRequestHeaders" "dst" "ingress.kubernetes.io/custom-request-headers" "val" "" -}}
{{-   $h2 := dict "src" "traefik.frontend.headers.customResponseHeaders" "dst" "ingress.kubernetes.io/custom-response-headers" "val" "" -}}
{{-   $h3 := dict "src" "traefik.frontend.headers.SSLRedirect" "dst" "ingress.kubernetes.io/ssl-redirect" "val" "" -}}
{{-   $h4 := dict "src" "traefik.frontend.redirect.entryPoint" "dst" "traefik.ingress.kubernetes.io/redirect-entry-point" "val" "" -}}
{{-   $customHeadersDef := list $h1 $h2 $h3 $h4 -}}
{{-   $labels := pluck "service" . | first | default dict | pluck "deploy" | first | default dict | pluck "labels" | first | default list -}}
{{-   $segments := list -}}
{{-   range $labelName, $labelValue := include "stack.helpers.normalizeDict" $labels | fromYaml -}}
{{-     $match := regexFind "traefik\\.(\\w+\\.)?frontend\\.rule" $labelName -}}
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
{{-     range $labelName, $labelValue := include "stack.helpers.normalizeDict" $labels | fromYaml -}}
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
{{-       if eq $labelName (regexReplaceAllLiteral "^traefik" "traefik.frontend.auth.basic.users" $segmentPrefix) -}}
{{-         $auth = $labelValue -}}
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


{{- define "stack.deployment" -}}
{{-   $Values := .Values -}}
{{-   $name := .name | replace "_" "-" -}}
{{-   $service := .service -}}
{{-   $kind := include "stack.helpers.deploymentKind" .service -}}
{{-   $replicas := 1 -}}
{{-   if .service.deploy -}}
{{-     $replicas = default 1 .service.deploy.replicas | int64 -}}
{{-   end -}}
{{-   $environments := include "stack.helpers.normalizeDict" .service.environment | fromYaml -}}
{{-   $volumes := include "stack.helpers.volumes" (dict "Values" $Values) | fromYaml -}}
{{-   $configs := include "stack.helpers.configs" (dict "Values" $Values) | fromYaml -}}
{{-   $secrets := include "stack.helpers.secrets" (dict "Values" $Values) | fromYaml -}}
{{-   $serviceVolumes := dict -}}
{{-   $volumeClaimTemplates := dict -}}
{{-   range $volIndex, $volValue := .service.volumes -}}
{{-     $list := splitList ":" $volValue -}}
{{-     $volName := first $list | replace "_" "-" -}}
{{-     if hasPrefix "/" $volName -}}
{{-       $_ := set $serviceVolumes (printf "%s-%d" $name $volIndex) (dict "hostPath" true "src" $volName "dst" (index $list 1)) -}}
{{-     else if hasPrefix "./" $volName -}}
{{-       $src := clean (printf "%s/%s" (default "." $Values.chdir) $volName) -}}
{{-       if not (isAbs $src) -}}
{{-         fail "volume path or chidir has to be absolute." -}}
{{-       end -}}
{{-       $_ := set $serviceVolumes (printf "%s-%d" $name $volIndex) (dict "hostPath" true "src" $src "dst" (index $list 1)) -}}
{{-     else -}}
{{-       $curr := get $volumes $volName -}}
{{-       $curr = merge $curr (dict "dst" (index $list 1)) -}}
{{-       $_ := set $serviceVolumes $volName $curr -}}
{{-       if eq $kind "StatefulSet" -}}
{{-         $_ := set $volumeClaimTemplates $volName $curr -}}
{{-       end -}}
{{-     end -}}
{{-   end -}}
{{-   range $volValue := .service.configs -}}
{{-       $volName := get $volValue "source" | replace "_" "-" -}}
{{-       $curr := get $configs $volName -}}
{{-       $_ := set $serviceVolumes $volName $curr -}}
{{-   end -}}
{{-   range $volValue := .service.secrets -}}
{{-       $volName := get $volValue "source" | replace "_" "-" -}}
{{-       $curr := get $secrets $volName -}}
{{-       $_ := set $serviceVolumes $volName $curr -}}
{{-   end -}}
{{-   $affinities := list -}}
{{-   $constraints := pluck "service" . | first | default dict | pluck "deploy" | first | default dict | pluck "placement" | first | default dict | pluck "constraints" | first | default list -}}
{{-   range $constraint := $constraints -}}
{{-     $op := "" -}}
{{-     $pair := list -}}
{{-     $curr := splitList "==" $constraint -}}
{{-     if eq (len $curr) 2 -}}
{{-       $op = "In" -}}
{{-       $pair = $curr -}}
{{-     end -}}
{{-     $curr := splitList "!=" $constraint -}}
{{-     if eq (len $curr) 2 -}}
{{-       $op = "NotIn" -}}
{{-       $pair = $curr -}}
{{-     end -}}
{{-     if and (not (contains "==" $constraint)) (not (contains "!=" $constraint)) (hasPrefix "node.labels" $constraint) -}}
{{-       $op = "Exists" -}}
{{-     end -}}
{{-     if or (eq $op "In") (eq $op "NotIn") -}}
{{-       $first := trim (first $pair) -}}
{{-       $last := trim (last $pair) -}}
{{-       if eq $first "node.role" -}}
{{-         $val := false -}}
{{-         if eq $op "In" -}}
{{-            $val = toString (eq $last "manager") -}}
{{-         else -}}
{{-           $val = toString (ne $last "manager") -}}
{{-         end -}}
{{-         $affinities = append $affinities (dict "key" "node-role.kubernetes.io/master" "operator" $op "values" (list $val)) -}}
{{-       end -}}
{{-       if eq $first "node.hostname" -}}
{{-         $affinities = append $affinities (dict "key" "kubernetes.io/hostname" "operator" $op "values" (list $last)) -}}
{{-       end -}}
{{-       if hasPrefix "node.labels" $first -}}
{{-         $affinities = append $affinities (dict "key" (replace "node.labels." ""  $first) "operator" $op "values" (list $last)) -}}
{{-       end -}}
{{-     end -}}
{{-     if (eq $op "Exists") -}}
{{-       if hasPrefix "node.labels" $constraint -}}
{{-         $affinities = append $affinities (dict "key" (replace "node.labels." "" $constraint) "operator" $op) -}}
{{-       end -}}
{{-     end -}}
{{-   end -}}
apiVersion: apps/v1
kind: {{ $kind }}
metadata:
  name: {{ $name | quote }}
spec:
  {{- if (and (ne $kind "DaemonSet") (ne $replicas 1)) }}
  replicas: {{ $replicas }}
  {{- end }}
  selector:
    matchLabels:
      service: {{ $name | quote }}
  {{- if eq $kind "StatefulSet" }}
  serviceName: {{ $name | quote }}
  {{- end }}
  template:
    metadata:
      labels:
        service: {{ $name | quote }}
    spec:
      {{- if $affinities }}
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions: {{ $affinities | toYaml | nindent 16 }}
      {{- end }}
      {{- if .service.imagePullSecrets }}
      imagePullSecrets:
        - name: {{ .service.imagePullSecrets }}
      {{- end }}
      {{- if .service.dns }}
      dnsPolicy: "None"
      dnsConfig:
        nameservers: {{ .service.dns | toYaml | nindent 10 }}
      {{- end }}
      containers:
        - name: {{ $name | quote }}
          image: {{ .service.image | quote }}
          {{- if .service.imagePullPolicy }}
          imagePullPolicy: {{ .service.imagePullPolicy }}
          {{- end }}
          {{- if .service.entrypoint }}
          command: {{ .service.entrypoint | toYaml | nindent 12 }}
          {{- end }}
          {{- if .service.command }}
          args: {{ .service.command | toYaml | nindent 12 }}
          {{- end }}
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
            {{- range $envName, $envValue := $environments }}
            - name: {{ $envName | quote }}
              value: {{ $envValue | quote }}
            {{- end -}}
          {{- end -}}
          {{- if $serviceVolumes }}
          volumeMounts:
            {{- range $volName, $volValue := $serviceVolumes -}}
            {{- if eq (get $volValue "volumeKind") "Volume" }}
            - mountPath: {{ "dst" | get $volValue | quote }}
              name: {{ $volName | quote }}
              {{- if "subPath" | get $volValue }}
              subPath: {{ "subPath" | get $volValue | quote }}
              {{- end }}
            {{- end -}}
            {{- if or (eq (get $volValue "volumeKind") "ConfigMap") (eq (get $volValue "volumeKind") "Secret") }}
            - mountPath: {{ "target" | get $volValue | dir | quote }}
              name: {{ $volName | quote }}
              {{- if "mode" | get $volValue }}
              mode: {{ "mode" | get $volValue }}
              {{- end }}
            {{- end -}}
            {{- end -}}
          {{- end }}
      {{- if and $serviceVolumes }}
      volumes:
        {{- range $volName, $volValue := $serviceVolumes -}}
        {{- if eq (get $volValue "volumeKind") "Volume" }}
        - name: {{ $volName | quote }}
          {{- if get $volValue "hostPath" }}
          hostPath:
            path: {{ get $volValue "src" | quote }}
          {{- else }}
          persistentVolumeClaim:
            claimName: {{ get $volValue "externalName" | quote }}
          {{- end -}}
        {{- end -}}
        {{- if eq (get $volValue "volumeKind") "ConfigMap" }}
        - name: {{ $volName | quote }}
          configMap:
            name: {{ get $volValue "externalName" | quote }}
        {{- end -}}
        {{- if eq (get $volValue "volumeKind") "Secret" }}
        - name: {{ $volName | quote }}
          secret:
            secretName: {{ get $volValue "externalName" | quote }}
        {{- end -}}
        {{- end -}}
      {{- end -}}
  {{- if $volumeClaimTemplates }}
  volumeClaimTemplates:
    {{- range $volName, $volValue := $volumeClaimTemplates -}}
    {{- $pvc := include "stack.pvc" (dict "volName" $volName "volValue" $volValue) | fromYaml }}
    - metadata: {{ get $pvc "metadata" | toYaml | nindent 8 }}
      spec: {{ get $pvc "spec" | toYaml | nindent 8  }}
    {{- end -}}
  {{- end -}}
{{- end -}}


{{- define "stack.service.loadBalancer" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ printf "%s-loadbalancer-%s" .name .protocol | replace "_" "-" | quote }}
spec:
  type: LoadBalancer
  ports:
    {{- range .ports }}
    - name: {{ printf "loadbalancer-%s" (get . "port" | default (get . "targetPort")) | lower | quote }}
      protocol: {{ get . "protocol" | quote }}
      port: {{ get . "port" | default (get . "targetPort") }}
      targetPort: {{ get . "targetPort" }}
    {{- end }}
  selector:
    service: {{ .name | quote }}
{{- end -}}


{{- define "stack.service.clusterIP" -}}
{{-   $name := .name | replace "_" "-" -}}
{{-   $ports := list -}}
{{-   if .service.ClusterIP -}}
{{-     $ports = get (include "stack.helpers.normalizePorts" .service.ClusterIP.ports | fromYaml) "all" -}}
{{-   end -}}
{{-   $labels := pluck "service" . | first | default dict | pluck "deploy" | first | default dict | pluck "labels" | first | default list -}}
{{-   $port := "" -}}
{{-   range $labelName, $labelValue := include "stack.helpers.normalizeDict" $labels | fromYaml -}}
{{-     if eq $labelName "traefik.port" -}}
{{-       $port = $labelValue -}}
{{-     end -}}
{{-   end -}}
{{-   if $port -}}
{{-     $existed := false -}}
{{-     range $ports -}}
{{-       if eq (get . "port" | default (get . "targetPort")) $port -}}
{{-         $existed = true -}}
{{-       end -}}
{{-     end -}}
{{-     if not $existed -}}
{{-       $ports = append $ports (dict "protocol" "TCP" "port" $port "targetPort" $port) -}}
{{-     end -}}
{{-   end -}}
{{- if $ports -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ printf "%s" $name | quote }}
spec:
  type: ClusterIP
  ports:
    {{- range $ports }}
    - name: {{ printf "clusterip-%s" (get . "port" | default (get . "targetPort")) | lower | quote }}
      protocol: {{ get . "protocol" | quote }}
      port: {{ get . "port" | default (get . "targetPort") }}
      targetPort: {{ get . "targetPort" }}
    {{- end }}
  selector:
    service: {{ $name | quote }}
{{- end -}}
{{- end -}}


{{- define "stack.service.nodePort" -}}
{{-   $name := .name | replace "_" "-" -}}
{{-   $ports := list -}}
{{-   if .service.NodePort -}}
{{-     $ports = get (include "stack.helpers.normalizePorts" .service.NodePort.ports | fromYaml) "all" -}}
{{-   end -}}
{{- if $ports -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ printf "%s-nodeport" $name | quote }}
spec:
  type: NodePort
  ports:
    {{- range $ports }}
    - name: {{ printf "nodeport-%s" (get . "port" | default (get . "targetPort")) | lower | quote }}
      protocol: {{ get . "protocol" | quote }}
      port: {{ get . "targetPort" }}
      targetPort: {{ get . "targetPort" }}
      {{- if get . "port" }}
      nodePort: {{ get . "port" }}
      {{- end }}
    {{- end }}
  selector:
    service: {{ $name | quote }}
{{- end -}}
{{- end -}}


{{- define "stack.ingress" -}}
{{- $name := .name -}}
{{- $segment := .segment -}}
{{- $hosts := .ingress.hosts -}}
{{- $port := .ingress.port -}}
{{- $backend := .ingress.backend -}}
{{- $auth := .ingress.auth -}}
{{- $pathPrefixStrip := .ingress.pathPrefixStrip -}}
{{- $addPrefix := .ingress.addPrefix -}}
{{- $customHeaders := .ingress.customHeaders -}}
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
    ingress.kubernetes.io/auth-secret: {{ printf "%s-basic-auth" $name | quote }}
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
              servicePort: {{ printf "clusterip-%s" $port | quote }}
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
  name: {{ printf "%s-%s-basic-auth" $name $segment | replace "_" "-" | quote}}
type: Opaque
data:
  auth: {{ $auth | b64enc }}
{{- end -}}


{{- define "stack.pvc" -}}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ .volName | quote }}
spec:
  accessModes:
    {{- if eq (get .volValue "type") "nfs" }}
    - ReadWriteMany
    {{- else }}
    - ReadWriteOnce
    {{- end }}
  {{- if get .volValue "dynamic" -}}
  {{- if ne (get .volValue "type") "none" }}
  storageClassName: {{ get .volValue "type" | quote }}
  {{- end -}}
  {{- else }}
  storageClassName: "manual"
  {{- end }}
  resources:
    requests:
      storage: {{ get .volValue "storage" | default "1Gi" | quote }}
{{- end -}}


{{- define "stack.pv" -}}
{{- $Values := .Values -}}
{{- $Namespace := .Release.Namespace -}}
apiVersion: v1
kind: PersistentVolume
metadata:
  name: {{ printf "%s-%s" $Namespace .volName | quote }}
spec:
  claimRef:
    namespace: {{ $Namespace }}
    name: {{ .volName | quote }}
  persistentVolumeReclaimPolicy: Delete
  accessModes:
    {{- if eq (get .volValue "type") "nfs" }}
    - ReadWriteMany
    {{- else }}
    - ReadWriteOnce
    {{- end }}
  capacity:
    storage: {{ get .volValue "storage" | default "1Gi" | quote }}
  {{- if and (ne (get .volValue "type") "nfs") (get .volValue "src") }}
  hostPath:
    path: {{ "src" | get .volValue | quote }}
  {{- end }}
  {{- if eq (get .volValue "type") "nfs" }}
  nfs:
    server: {{ "server" | get .volValue | quote }}
    path: {{ "src" | get .volValue | quote }}
  {{- end -}}
{{- end -}}


{{- define "stack.configMap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .volName | quote }}
{{- if get .volValue "data" }}  
data: {{ get .volValue "data" | toYaml | nindent 2 }}
{{- end -}}
{{- end -}}


{{- define "stack.secret" -}}
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: {{ .volName | quote }}
{{- if get .volValue "data" }}  
data: {{ get .volValue "data" | toYaml | nindent 2 }}
{{- end }}
{{- if get .volValue "stringData" }}  
data: {{ get .volValue "data" | toYaml | nindent 2 }}
{{- end -}}
{{- end -}}