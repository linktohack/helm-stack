{{/*
Kind of the deployment
*/}}
{{- define "stack.helpers.deploymentKind" -}}
{{-   $kind := "Deployment" -}}
{{-   $mode := . | pluck "deploy" | first | default dict | pluck "mode" | first | default "replicated" -}}
{{-   if eq $mode "global" -}}
{{-      $kind = "DaemonSet" -}}
{{-   end -}}
{{-   if .kind -}}
{{-     $kind = .kind -}}
{{-   end -}}
{{ $kind }}
{{- end -}}


{{- define "stack.deployment" -}}
{{-   $name := .name | replace "_" "-" -}}
{{-   $service := .service -}}
{{-   $Values := .Values -}}
{{-   $kind := include "stack.helpers.deploymentKind" $service -}}
{{-   $replicas := $service | pluck "deploy"| first | default dict | pluck "replicas" | first | default 1 | int64 -}}
{{-   $environments := include "stack.helpers.normalizeKV" $service.environment | fromYaml -}}
{{-   $volumes := include "stack.helpers.volumes" (dict "Values" $Values) | fromYaml -}}
{{-   $configs := include "stack.helpers.configs" (dict "Values" $Values) | fromYaml -}}
{{-   $secrets := include "stack.helpers.secrets" (dict "Values" $Values) | fromYaml -}}
{{-   $serviceVolumes := dict -}}
{{-   $volumeClaimTemplates := dict -}}
{{-   range $volIndex, $volValue := $service.volumes -}}
{{-     $list := splitList ":" $volValue -}}
{{-     $volName := first $list -}}
{{-     if hasPrefix "/" $volName -}}
{{-       $_ := set $serviceVolumes (printf "volume-%d" $volIndex) (dict "volumeKind" "Volume" "type" "hostPath" "src" $volName "dst" (index $list 1)) -}}
{{-     else if hasPrefix "./" $volName -}}
{{-       $src := clean (printf "%s/%s" (default "." $Values.chdir) $volName) -}}
{{-       if not (isAbs $src) -}}
{{-         fail "volume path or chidir has to be absolute." -}}
{{-       end -}}
{{-       $_ := set $serviceVolumes (printf "volume-%d" $volIndex) (dict "volumeKind" "Volume" "type" "hostPath" "src" $src "dst" (index $list 1)) -}}
{{-     else -}}
{{-       $volName = $volName | replace "_" "-" -}}
{{-       $curr := get $volumes $volName -}}
{{-       $curr = merge $curr (dict "dst" (index $list 1)) -}}
{{-       $_ := set $serviceVolumes $volName $curr -}}
{{-       if eq $kind "StatefulSet" -}}
{{-         $_ := set $volumeClaimTemplates $volName $curr -}}
{{-       end -}}
{{-     end -}}
{{-   end -}}
{{-   range $volValue := $service.configs -}}
{{-       $volName := get $volValue "source" | replace "_" "-" -}}
{{-       $curr := get $configs $volName | deepCopy -}}
{{-       $curr = merge $curr $volValue -}}
{{-       $_ := set $serviceVolumes $volName $curr -}}
{{-   end -}}
{{-   range $volValue := $service.secrets -}}
{{-       $volName := get $volValue "source" | replace "_" "-" -}}
{{-       $curr := get $secrets $volName | deepCopy -}}
{{-       $curr = merge $curr $volValue -}}
{{-       $_ := set $serviceVolumes $volName $curr -}}
{{-   end -}}
{{-   $affinities := list -}}
{{-   $constraints := . | pluck "service" | first | default dict | pluck "deploy" | first | default dict | pluck "placement" | first | default dict | pluck "constraints" | first | default list -}}
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
      {{- if $service.dns }}
      dnsPolicy: "None"
      dnsConfig:
        nameservers: {{ $service.dns | toYaml | nindent 10 }}
      {{- end }}
      containers:
        - name: {{ $service.container_name | default $name | replace "_" "-" | quote }}
          image: {{ $service.image | quote }}
          {{- if $service.entrypoint }}
          command: {{ $service.entrypoint | include "stack.helpers.normalizeEntrypoint" | nindent 12 }}
          {{- end }}
          {{- if $service.hostname }}
          hostname: {{ $service.hostname | quote }}
          {{- end }}
          {{- if $service.command }}
          args: {{ $service.command | include "stack.helpers.normalizeCommand" | nindent 12 }}
          {{- end }}
          {{- if or $service.privileged $service.cap_add $service.cap_drop }}
          securityContext:
            {{- if $service.privileged }}
            privileged: {{ $service.privileged }}
            {{- end }}
            {{- if or $service.cap_add $service.cap_drop }}
            capabilities:
              {{- if $service.cap_add }}
              add: {{ $service.cap_add | toYaml | nindent 16 }}
              {{- end }}
              {{- if $service.cap_drop }}
              drop: {{ $service.cap_drop | toYaml | nindent 16 }}
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
            - mountPath: {{ get $volValue "dst" | quote }}
              name: {{ $volName | quote }}
              {{- if get $volValue "subPath" }}
              subPath: {{ get $volValue "subPath" | quote }}
              {{- end }}
            {{- end -}}
            {{- if or (eq (get $volValue "volumeKind") "ConfigMap") (eq (get $volValue "volumeKind") "Secret") }}
            - mountPath: {{ get $volValue "target" | quote }}
              name: {{ $volName | quote }}
              {{- if get $volValue "file" }}
              subPath: {{ get $volValue "file" | quote }}
              {{- end }}
            {{- end -}}
            {{- end -}}
          {{- end }}
          {{- if and $service.healthcheck ($service.healthcheck | pluck "test" | first) (not ($service.healthcheck | pluck "disabled" | first)) -}}
          {{ $healthCheckCommand := include "stack.helpers.normalizeHealthCheckCommand" $service.healthcheck.test | fromYaml -}}
          {{- if $healthCheckCommand }}
          livenessProbe:
            exec:
              command: {{ include "stack.helpers.normalizeHealthCheckCommand" $service.healthcheck.test | nindent 16 }}
            {{- if $service.healthcheck.start_period }}
            initialDelaySeconds: {{ include "stack.helpers.normalizeDuration" $service.healthcheck.start_period }}
            {{- end }}
            {{- if $service.healthcheck.interval }}
            periodSeconds: {{ include "stack.helpers.normalizeDuration" $service.healthcheck.interval }}
            {{- end }}
            {{- if $service.healthcheck.timeout }}
            timeoutSeconds: {{ include "stack.helpers.normalizeDuration" $service.healthcheck.timeout }}
            {{- end }}
            {{- if $service.healthcheck.retries }}
            failureThreshold: {{ $service.healthcheck.retries }}
            {{- end }}
          {{- end }}
          {{- end }}
          {{- if $service.imagePullPolicy }}
          imagePullPolicy: {{ $service.imagePullPolicy }}
          {{- end }}
      {{- if and $serviceVolumes }}
      volumes:
        {{- range $volName, $volValue := $serviceVolumes -}}
        {{- if eq (get $volValue "volumeKind") "Volume" }}
        - name: {{ $volName | quote }}
          {{- if get $volValue "type" | eq "hostPath" }}
          hostPath:
            path: {{ get $volValue "src" | quote }}
          {{- else if get $volValue "type" | eq "emptyDir" }}
          emptyDir: {}
          {{- else }}
          persistentVolumeClaim:
            claimName: {{ get $volValue "externalName" | quote }}
          {{- end -}}
        {{- end -}}
        {{- if eq (get $volValue "volumeKind") "ConfigMap" }}
        - name: {{ $volName | quote }}
          configMap:
            name: {{ get $volValue "externalName" | quote }}
            {{- if get $volValue "mode" }}
            defaultMode: {{ get $volValue "mode" }}
            {{- end }}
        {{- end -}}
        {{- if eq (get $volValue "volumeKind") "Secret" }}
        - name: {{ $volName | quote }}
          secret:
            secretName: {{ get $volValue "externalName" | quote }}
        {{- end -}}
        {{- end -}}
      {{- end -}}
      {{- if $service.imagePullSecrets }}
      imagePullSecrets:
        - name: {{ $service.imagePullSecrets }}
      {{- end }}
      {{- if $service.serviceAccountName }}
      serviceAccountName: {{ $service.serviceAccountName }}
      {{- end }}
  {{- if $volumeClaimTemplates }}
  volumeClaimTemplates:
    {{- range $volName, $volValue := $volumeClaimTemplates -}}
    {{- $pvc := include "stack.pvc" (dict "volName" $volName "volValue" $volValue) | fromYaml }}
    - metadata: {{ get $pvc "metadata" | toYaml | nindent 8 }}
      spec: {{ get $pvc "spec" | toYaml | nindent 8  }}
    {{- end -}}
  {{- end -}}
{{- end -}}

