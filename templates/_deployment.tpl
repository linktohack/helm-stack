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


{{- define "stack.helpers.podSpec" -}}
{{-   $name := .name | replace "_" "-" -}}
{{-   $service := .service -}}
{{-   $containers := .containers -}}
{{-   $serviceVolumes := .serviceVolumes -}}
{{-   $volumeMounts := .volumeMounts -}}
{{-   $constraints := .constraints -}}
{{-   $restartPolicy := .restartPolicy -}}
{{-   $restartPolicyConditions := dict "" "" "none" "Never" "on-failure" "OnFailure" "any" "Always" -}}
{{-   $affinities := list -}}
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
{{-         $val := toString (eq $last "manager") -}}
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
  {{- range $containerIndex, $container := $containers -}}
  {{ if eq $containerIndex 999 }}
  {{ $container | toYaml | nindent 2 | fail }}
  {{ end }}
  {{ $environments := include "stack.helpers.normalizeKV" $container.environment | fromYaml -}}
  {{ $volumeMount := index $volumeMounts $containerIndex -}}
  {{-     $maybeWithContainerIndex := "" -}}
  {{-     if gt $containerIndex -1 -}}
  {{-       $maybeWithContainerIndex = printf "-%d" $containerIndex -}}
  {{-     end }}
    - name: {{ $container.container_name | default (printf "%s%s" $name $maybeWithContainerIndex) | replace "_" "-" | quote }}
      image: {{ $container.image | quote }}
      {{- if $container.entrypoint }}
      command: {{ $container.entrypoint | include "stack.helpers.normalizeEntrypoint" | nindent 12 }}
      {{- end }}
      {{- if $container.hostname }}
      hostname: {{ $container.hostname | quote }}
      {{- end }}
      {{- if $container.command }}
      args: {{ $container.command | include "stack.helpers.normalizeCommand" | nindent 12 }}
      {{- end }}
      {{- if or $container.privileged $container.cap_add $container.cap_drop }}
      securityContext:
        {{- if $container.privileged }}
        privileged: {{ $container.privileged }}
        {{- end }}
        {{- if or $container.cap_add $container.cap_drop }}
        capabilities:
          {{- if $container.cap_add }}
          add: {{ $container.cap_add | toYaml | nindent 16 }}
          {{- end }}
          {{- if $container.cap_drop }}
          drop: {{ $container.cap_drop | toYaml | nindent 16 }}
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
      {{- if $volumeMount }}
      volumeMounts:
        {{- range $volName, $volValue := $volumeMount -}}
        {{- if eq (get $volValue "volumeKind") "Volume" }}
        - mountPath: {{ get $volValue "dst" | quote }}
          name: {{ $volName | quote }}
          {{- if get $volValue "subPath" }}
          subPath: {{ get $volValue "subPath" | quote }}
          {{- end }}
        {{- end -}}
        {{- if eq (get $volValue "volumeKind") "ConfigMap" }}
        - mountPath: {{ get $volValue "target" | default (printf "/%s" (get $volValue "originalName")) | quote }}
          name: {{ $volName | quote }}
          {{- if get $volValue "file" }}
          subPath: {{ get $volValue "file" | base | quote }}
          {{- end }}
        {{- end -}}
        {{- if eq (get $volValue "volumeKind") "Secret" }}
        - mountPath: {{ get $volValue "target" | default (printf "/run/secrets/%s" (get $volValue "originalName")) | quote }}
          name: {{ $volName | quote }}
          {{- if get $volValue "file" }}
          subPath: {{ get $volValue "file" | base | quote }}
          {{- end }}
        {{- end -}}
        {{- end -}}
      {{- end }}
      {{- if and $container.healthcheck ($container.healthcheck | pluck "test" | first) (not ($container.healthcheck | pluck "disabled" | first)) -}}
      {{ $healthCheckCommand := include "stack.helpers.normalizeHealthCheckCommand" $container.healthcheck.test | fromYaml -}}
      {{- if $healthCheckCommand }}
      livenessProbe:
        exec:
          command: {{ include "stack.helpers.normalizeHealthCheckCommand" $container.healthcheck.test | nindent 16 }}
        {{- if $container.healthcheck.start_period }}
        initialDelaySeconds: {{ include "stack.helpers.normalizeDuration" $container.healthcheck.start_period }}
        {{- end }}
        {{- if $container.healthcheck.interval }}
        periodSeconds: {{ include "stack.helpers.normalizeDuration" $container.healthcheck.interval }}
        {{- end }}
        {{- if $container.healthcheck.timeout }}
        timeoutSeconds: {{ include "stack.helpers.normalizeDuration" $container.healthcheck.timeout }}
        {{- end }}
        {{- if $container.healthcheck.retries }}
        failureThreshold: {{ $container.healthcheck.retries }}
        {{- end }}
      {{- end }}
      {{- end }}
      {{- if $container.imagePullPolicy }}
      imagePullPolicy: {{ $container.imagePullPolicy }}
      {{- end }}
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
  {{- if get $restartPolicyConditions (get $restartPolicy "condition") }}
  restartPolicy: {{ get $restartPolicyConditions (get $restartPolicy "condition") }}
  {{- end }}
{{- end -}}


{{- define "stack.deployment" -}}
{{-   $name := .name | replace "_" "-" -}}
{{-   $service := .service -}}
{{-   $Values := .Values -}}
{{-   $kind := include "stack.helpers.deploymentKind" $service -}}
{{-   $replicas := $service | pluck "deploy"| first | default dict | pluck "replicas" | first | default 1 | int64 -}}
{{-   $volumes := include "stack.helpers.volumes" (dict "Values" $Values) | fromYaml -}}
{{-   $configs := include "stack.helpers.configs" (dict "Values" $Values) | fromYaml -}}
{{-   $secrets := include "stack.helpers.secrets" (dict "Values" $Values) | fromYaml -}}
{{-   $serviceVolumes := dict -}}
{{-   $volumeMounts := list -}}
{{-   $volumeClaimTemplates := dict -}}
{{-   $constraints := . | pluck "service" | first | default dict | pluck "deploy" | first | default dict | pluck "placement" | first | default dict | pluck "constraints" | first | default list -}}
{{-   $restartPolicy := . | pluck "service" | first | default dict | pluck "deploy" | first | default dict | pluck "restart_policy" | first | default dict -}}
{{-   $containers := omit $service "containers" | prepend ($service.containers | default list) -}}
{{-   range $containerIndex, $container := $containers -}}
{{-     $volumeMount := dict -}}
{{-     $maybeWithContainerIndex := "" -}}
{{-     if gt $containerIndex 0 -}}
{{-       $maybeWithContainerIndex = printf "-%d" $containerIndex -}}
{{-     end -}}
{{-     range $volIndex, $volValue := $container.volumes -}}
{{-       $list := splitList ":" $volValue -}}
{{-       $volName := first $list -}}
{{-       if hasPrefix "/" $volName -}}
{{-         $_ := set $serviceVolumes (printf "volume%s-%d" $maybeWithContainerIndex $volIndex) (dict "volumeKind" "Volume" "type" "hostPath" "src" $volName "dst" (index $list 1)) -}}
{{-         $_ := set $volumeMount (printf "volume%s-%d" $maybeWithContainerIndex $volIndex) (dict "volumeKind" "Volume" "type" "hostPath" "src" $volName "dst" (index $list 1)) -}}
{{-       else if hasPrefix "./" $volName -}}
{{-         $src := clean (printf "%s/%s" (default "." $Values.chdir) $volName) -}}
{{-         if not (isAbs $src) -}}
{{-           fail "volume path or chidir has to be absolute." -}}
{{-         end -}}
{{-         $_ := set $serviceVolumes (printf "volume%s-%d" $maybeWithContainerIndex $volIndex) (dict "volumeKind" "Volume" "type" "hostPath" "src" $src "dst" (index $list 1)) -}}
{{-         $_ := set $volumeMount (printf "volume%s-%d" $maybeWithContainerIndex $volIndex) (dict "volumeKind" "Volume" "type" "hostPath" "src" $src "dst" (index $list 1)) -}}
{{-       else -}}
{{-         $volName = $volName | replace "_" "-" -}}
{{-         $curr := get $volumes $volName | deepCopy -}}
{{-         $curr = mergeOverwrite $curr (dict "dst" (index $list 1)) -}}
{{-         $_ := set $volumeMount $volName $curr -}}
{{-         if and (eq $kind "StatefulSet") (ne (get $curr "type") "emptyDir") (get $curr "dynamic") -}}
{{-           $_ := set $volumeClaimTemplates $volName $curr -}}
{{-         else -}}
{{-           $_ := set $serviceVolumes $volName $curr -}}
{{-         end -}}
{{-       end -}}
{{-     end -}}
{{-     range $volValue := $container.configs -}}
{{-       if (typeOf $volValue) | ne "string" -}}
{{-         $volName := get $volValue "source" | replace "_" "-" -}}
{{-         $curr := get $configs $volName | deepCopy -}}
{{-         $curr = mergeOverwrite $curr $volValue -}}
{{-         $_ := set $serviceVolumes $volName $curr -}}
{{-         $_ := set $volumeMount $volName $curr -}}
{{-       else -}}
{{-         $volName := $volValue | replace "_" "-" -}}
{{-         $_ := set $serviceVolumes $volName (get $configs $volName) -}}
{{-         $_ := set $volumeMount $volName (get $configs $volName) -}}
{{-       end -}}
{{-     end -}}
{{-     range $volValue := $container.secrets -}}
{{-       if (typeOf $volValue) | ne "string" -}}
{{-         $volName := get $volValue "source" | replace "_" "-" -}}
{{-         $curr := get $secrets $volName | deepCopy -}}
{{-         $curr = mergeOverwrite $curr $volValue -}}
{{-         $_ := set $serviceVolumes $volName $curr -}}
{{-         $_ := set $volumeMount $volName $curr -}}
{{-       else -}}
{{-         $volName := $volValue | replace "_" "-" -}}
{{-         $_ := set $serviceVolumes $volName (get $secrets $volName) -}}
{{-         $_ := set $volumeMount $volName (get $secrets $volName) -}}
{{-       end -}}
{{-     end -}}
{{-     $volumeMounts = append $volumeMounts $volumeMount -}}
{{-   end -}}
{{- $podSpec := include "stack.helpers.podSpec" (dict "name" $name "service" $service "containers" $containers "serviceVolumes" $serviceVolumes "volumeMounts" $volumeMounts "constraints" $constraints "restartPolicy" $restartPolicy) | fromYaml -}}
{{- if eq $kind "Job" -}}
apiVersion: batch/v1
kind: {{ $kind }}
metadata:
  name: {{ $name | quote }}
spec:
  template:
    {{ mergeOverwrite (dict "spec" (dict "restartPolicy" "Never") $podSpec) | toYaml | nindent 4 }}
{{- else if eq $kind "CronJob" -}}
apiVersion: batch/v1beta1
kind: {{ $kind }}
metadata:
  name: {{ $name | quote }}
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        {{ mergeOverwrite (dict "spec" (dict "restartPolicy" "Never") $podSpec) | toYaml | nindent 8 }}
{{- else -}}
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
    {{ $podSpec | toYaml | nindent 4 }}
  {{- if $volumeClaimTemplates }}
  volumeClaimTemplates:
    {{- range $volName, $volValue := $volumeClaimTemplates -}}
    {{- $pvc := include "stack.pvc" (dict "volName" $volName "volValue" $volValue) | fromYaml }}
    - metadata: {{ get $pvc "metadata" | toYaml | nindent 8 }}
      spec: {{ get $pvc "spec" | toYaml | nindent 8  }}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

