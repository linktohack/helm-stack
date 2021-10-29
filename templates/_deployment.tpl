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


{{/*
Affinity from constraint
*/}}
{{- define "stack.helpers.affinityFromConstraint" -}}
{{-   $constraint := . -}}
{{-   $affinity := dict -}}
{{-   $op := "" -}}
{{-   $pair := list -}}
{{-   $curr := splitList "==" $constraint -}}
{{-   if eq (len $curr) 2 -}}
{{-     $op = "In" -}}
{{-     $pair = $curr -}}
{{-   end -}}
{{-   $curr := splitList "!=" $constraint -}}
{{-   if eq (len $curr) 2 -}}
{{-     $op = "NotIn" -}}
{{-     $pair = $curr -}}
{{-   end -}}
{{-   if and (not (contains "==" $constraint)) (not (contains "!=" $constraint)) (hasPrefix "node.labels" $constraint) -}}
{{-     $op = "Exists" -}}
{{-   end -}}
{{-   if or (eq $op "In") (eq $op "NotIn") -}}
{{-     $first := trim (first $pair) -}}
{{-     $last := trim (last $pair) -}}
{{-     if eq $first "node.role" -}}
{{-       $val := toString (eq $last "manager") -}}
{{-       $affinity = dict "key" "node-role.kubernetes.io/master" "operator" $op "values" (list $val) -}}
{{-       end -}}
{{-     if eq $first "node.hostname" -}}
{{-       $affinity = dict "key" "kubernetes.io/hostname" "operator" $op "values" ($last | list) -}}
{{-     end -}}
{{-     if hasPrefix "node.labels" $first -}}
{{-       $affinity = dict "key" (replace "node.labels." "" $first) "operator" $op "values" ($last | list) -}}
{{-     end -}}
{{-   end -}}
{{-   if (eq $op "Exists") -}}
{{-     if hasPrefix "node.labels" $constraint -}}
{{-       $affinity = dict "key" (replace "node.labels." "" $constraint) "operator" $op -}}
{{-     end -}}
{{-   end -}}
{{ $affinity | toYaml }}
{{- end -}}

{{- define "stack.helpers.normalizeToleration" -}}
{{-   $toleration := dict -}}
{{-   if eq (typeOf .) "string" -}}
{{-     if not (regexMatch "^[^=:]+(=[^=:]+)?(:(NoSchedule|PreferNoSchedule|NoExecute))?$" .) -}}
{{-       fail "deploy.placement.tolerations[] should match 'key[=value][:(NoSchedule|PreferNoSchedule|NoExecute)]'" -}}
{{-     end -}}
{{-     $list := splitList ":" . -}}
{{-     if eq (len $list) 2 -}}
{{-       $_ := set $toleration "effect" (index $list 1) -}}
{{-     end -}}
{{-     $pair := index $list 0 | splitList "=" -}}
{{-     $_ := set $toleration "key" (index $pair 0) -}}
{{-     if eq (len $pair) 1 -}}
{{-       $_ := set $toleration "operator" "Exists" -}}
{{-     else -}}
{{-       $_ := set $toleration "operator" "Equal" -}}
{{-       $_ := set $toleration "value" (index $pair 1) -}}
{{-     end -}}
{{-   else -}}
{{-     $toleration = .}}
{{-   end -}}
{{ $toleration | toYaml }}
{{-   end -}}


{{- define "stack.helpers.containerSpec" -}}
{{- $container := . -}}
name: {{ $container.name | quote }}
image: {{ $container.image | quote }}
{{- if $container.entrypoint }}
command: {{ $container.entrypoint | include "stack.helpers.normalizeEntrypoint" | nindent 2 }}
{{- end -}}
{{- if $container.command }}
args: {{ $container.command | include "stack.helpers.normalizeCommand" | nindent 2 }}
{{- end -}}
{{- if $container.hostname }}
hostname: {{ $container.hostname | quote }}
{{- end -}}
{{- $resources := $container | pluck "deploy" | first | default dict | pluck "resources" | first | default dict -}}
{{- if $resources }}
resources:
  requests: {{ $resources.reservations | default $resources.requests | include "stack.helpers.normalizeCPU" | nindent 4 }}
  limits: {{ $resources.limits | include "stack.helpers.normalizeCPU" | nindent 4 }}
{{- end -}}
{{- if or $container.privileged $container.cap_add $container.cap_drop }}
securityContext:
  {{- if $container.privileged }}
  privileged: {{ $container.privileged }}
  {{- end -}}
  {{- if or $container.cap_add $container.cap_drop }}
  capabilities:
    {{- if $container.cap_add }}
    add: {{ $container.cap_add | toYaml | nindent 6 }}
    {{- end -}}
    {{- if $container.cap_drop }}
    drop: {{ $container.cap_drop | toYaml | nindent 6 }}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if $container.environment }}
env:
  {{- range $envName, $envValue := $container.environment }}
  - name: {{ $envName | quote }}
    value: {{ $envValue | quote }}
  {{- end -}}
{{- end -}}
{{- if $container.volumeMounts }}
volumeMounts:
  {{- range $mount := $container.volumeMounts -}}
  {{- $volName := $mount.name -}}
  {{- if eq $mount.volumeKind "Volume" }}
  - mountPath: {{ $mount.target | quote }}
    name: {{ $mount.name | quote }}
    {{- if $mount.subPath }}
    subPath: {{ $mount.subPath | quote }}
    {{- end -}}
    {{- if $mount.readOnly }}
    readOnly: {{ $mount.readOnly }}
    {{- end }}
  {{- end -}}
  {{- if or (eq $mount.volumeKind "ConfigMap") (eq $mount.volumeKind "Secret") }}
  - mountPath: {{ $mount.target | quote }}
    name: {{ $mount.name | quote }}
    {{- $subPath := $mount.subPath | default $mount.file -}}
    {{- if $subPath }}
    subPath: {{ $subPath | base | quote }}
    {{- end -}}
  {{- end -}}
  {{- end -}}
{{- end -}}
{{- if and $container.healthcheck ($container.healthcheck | pluck "test" | first) (not ($container.healthcheck | pluck "disabled" | first)) -}}
{{ $healthCheckCommand := include "stack.helpers.normalizeHealthCheckCommand" $container.healthcheck.test | fromYaml -}}
{{- if $healthCheckCommand }}
livenessProbe:
  exec:
    command: {{ include "stack.helpers.normalizeHealthCheckCommand" $container.healthcheck.test | nindent 4 }}
  {{- if $container.healthcheck.start_period }}
  initialDelaySeconds: {{ include "stack.helpers.normalizeDuration" $container.healthcheck.start_period }}
  {{- end -}}
  {{- if $container.healthcheck.interval }}
  periodSeconds: {{ include "stack.helpers.normalizeDuration" $container.healthcheck.interval }}
  {{- end -}}
  {{- if $container.healthcheck.timeout }}
  timeoutSeconds: {{ include "stack.helpers.normalizeDuration" $container.healthcheck.timeout }}
  {{- end -}}
  {{- if $container.healthcheck.retries }}
  failureThreshold: {{ $container.healthcheck.retries }}
  {{- end -}}
{{- end -}}
{{- end -}}
{{- if $container.imagePullPolicy }}
imagePullPolicy: {{ $container.imagePullPolicy }}
{{- end -}}
{{- end -}}


{{/*
List of container specs
Result is a dict { "list": $containerList }
*/}}
{{- define "stack.helpers.containerList" -}}
{{-   $name := .name -}}
{{-   $kind := .kind -}}
{{-   $volumes := .volumes -}}
{{-   $configs := .configs -}}
{{-   $secrets := .secrets -}}
{{-   $containers := .containers -}}
{{-   $Values := .Values -}}
{{- /* TODO: current implementation mutates parent data */ -}}
{{-   $podVolumes := .podVolumes -}}
{{-   $containerList := list }}
{{-   range $index, $container := $containers -}}
{{-     $maybeWithContainerIndex := "" -}}
{{-     if gt $index 0 -}}
{{-       $maybeWithContainerIndex = printf "-%d" $index -}}
{{-     end -}}
{{-     $volumeMounts := list -}}
{{- /* pv */ -}}
{{-     range $volIndex, $volValue := $container.volumes -}}
{{-       $mountOptions := include "stack.helpers.normalizeVolumeMount" $volValue | fromYaml -}}
{{-       $volName := $mountOptions.source -}}
{{- /* pv: hostPath */ -}}
{{-       if hasPrefix "/" $volName -}}
{{-         $name := printf "volume%s-%d" $maybeWithContainerIndex $volIndex -}}
{{-         $meta := dict "volumeKind" "Volume" "name" $name "type" "hostPath" -}}
{{-         $volume := merge $meta $mountOptions -}}
{{-         $volumeMounts = append $volumeMounts $volume -}}
{{-         $_ := set $podVolumes $name $volume -}}
{{-       else if hasPrefix "./" $volName -}}
{{-         $src := clean (printf "%s/%s" (default "." $Values.chdir) $volName) -}}
{{-         if not (isAbs $src) -}}
{{-           fail "volume path or chdir has to be absolute." -}}
{{-         end -}}
{{-         $name := printf "volume%s-%d" $maybeWithContainerIndex $volIndex -}}
{{-         $meta := dict "volumeKind" "Volume" "name" $name "type" "hostPath" "source" $src -}}
{{-         $volume := merge $meta $mountOptions -}}
{{-         $volumeMounts = append $volumeMounts $volume -}}
{{-         $_ := set $podVolumes $name $volume -}}
{{- /* pv: else */ -}}
{{-       else -}}
{{-         $name := $volName | replace "_" "-" -}}
{{-         $volume := merge (dict "name" $name) $mountOptions (get $volumes $name) -}}
{{-         $volumeMounts = append $volumeMounts $volume -}}
{{-         if and (eq $kind "StatefulSet") (ne $volume.type "emptyDir") (not $volume.external) (get $volume "dynamic") -}}
{{-         else -}}
{{-           $_ := set $podVolumes $name $volume -}}
{{-         end -}}
{{-       end -}}
{{-     end -}}
{{- /* config */ -}}
{{-     range $volValue := $container.configs -}}
{{-       $mountOptions := include "stack.helpers.normalizeConfigMount" $volValue | fromYaml -}}
{{-       $name := $mountOptions.source | replace "_" "-" -}}
{{-       $volume := merge (dict "name" $name) $mountOptions (get $configs $name) -}}
{{-       $volumeMounts = append $volumeMounts $volume -}}
{{-       $_ := set $podVolumes $name $volume -}}
{{-     end -}}
{{- /* secret */ -}}
{{-     range $volValue := $container.secrets -}}
{{-       $mountOptions := include "stack.helpers.normalizeSecretMount" $volValue | fromYaml -}}
{{-       $name := $mountOptions.source | replace "_" "-" -}}
{{-       $volume := merge (dict "name" $name) $mountOptions (get $secrets $name) -}}
{{-       $volumeMounts = append $volumeMounts $volume -}}
{{-       $_ := set $podVolumes $name $volume -}}
{{-     end -}}
{{-     $name := $container.container_name | default $container.name | default (printf "%s%s" $name $maybeWithContainerIndex) | replace "_" "-" -}}
{{-     $environment := include "stack.helpers.normalizeKV" $container.environment | fromYaml -}}
{{-     $_ := set $container "environment" $environment -}}
{{-     $_ := set $container "volumeMounts" $volumeMounts -}}
{{-     $_ := set $container "name" $name -}}
{{-     $containerList = append $containerList (include "stack.helpers.containerSpec" $container | fromYaml) }}
{{-   end -}}
list: {{ $containerList | toYaml | nindent 2 }}
{{- end -}}


{{- define "stack.helpers.podSpec" -}}
{{-   $name := .name | replace "_" "-" -}}
{{-   $kind := .kind -}}
{{-   $service := .service -}}
{{-   $configs := .configs -}}
{{-   $secrets := .secrets -}}
{{-   $volumes := .volumes -}}
{{-   $containers := .containers -}}
{{-   $initContainers := .initContainers -}}
{{-   $placement := .placement -}}
{{-   $restartPolicy := .restartPolicy -}}
{{-   $restartPolicyMap := dict "" "" "none" "Never" "on-failure" "OnFailure" "any" "Always" -}}
{{- /* TODO: current implementation mutates parent data */ -}}
{{-   $podVolumes := dict -}}
spec:
  {{- /* affinities */ -}}
  {{- $constraints := $placement.constraints -}}
  {{- if $constraints }}
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
            {{- range $constraint := $constraints }}
            - {{ include "stack.helpers.affinityFromConstraint" $constraint | indent 14 | trim }}
            {{- end }}
  {{- end }}
  {{- /* tolerations */ -}}
  {{- $tolerations := $placement.tolerations -}}
  {{- if $tolerations }}
  tolerations:
  {{- range $toleration := $tolerations }}
  - {{ include "stack.helpers.normalizeToleration" $toleration | indent 4 | trim }}
  {{- end }}
  {{- end }}
  {{- /* dns */ -}}
  {{- if $service.dns }}
  dnsPolicy: "None"
  dnsConfig:
    nameservers: {{ $service.dns | toYaml | nindent 10 }}
  {{- end }}
  {{/* containers */}}
  containers: {{ include "stack.helpers.containerList" (dict "name" $name "service" $service "kind" $kind "configs" $configs "secrets" $secrets "volumes" $volumes "podVolumes" $podVolumes "containers" $containers "Values" .Values) | fromYaml | pluck "list" | first | toYaml | nindent 6 }}
  {{/* initContainers */}}
  {{- if $initContainers }}
  initContainers: {{ include "stack.helpers.containerList" (dict "name" (printf "%s-init" $name) "service" $service "kind" $kind "configs" $configs "secrets" $secrets "volumes" $volumes "podVolumes" $podVolumes "containers" (deepCopy $initContainers) "Values" .Values) | fromYaml | pluck "list" | first | toYaml | nindent 6 }}
  {{- end }}
  {{- /* hostNetwork */ -}}
  {{- if eq "host" ($containers | first | pluck "network_mode" | first | default "default") }}
  hostNetwork: true
  {{- end }}
  {{- if $podVolumes }}
  volumes:
  {{- range $volValue := $podVolumes }}
  {{-   $volName := $volValue.name }}
    - name: {{ $volName | quote }}
    {{- if eq $volValue.volumeKind "Volume" }}
      {{- if eq $volValue.type "hostPath" }}
      hostPath:
        path: {{ $volValue.src | default $volValue.source | quote }}
      {{- else if eq $volValue.type "emptyDir" }}
      emptyDir: {}
      {{- else }}
      persistentVolumeClaim:
        claimName: {{ $volValue.externalName | quote }}
      {{- end }}
    {{- end }}
    {{- if eq $volValue.volumeKind "ConfigMap" }}
      configMap:
        name: {{ $volValue.externalName | quote }}
        {{- if $volValue.mode }}
        defaultMode: {{ $volValue.mode }}
        {{- end }}
    {{- end }}
    {{- if eq $volValue.volumeKind "Secret" }}
      secret:
        secretName: {{ $volValue.externalName | quote }}
        {{- if $volValue.mode }}
        defaultMode: {{ $volValue.mode }}
        {{- end }}
    {{- end }}
  {{- end }}
  {{- end }}
  {{- /* imagePullSecrets */ -}}
  {{- if $service.imagePullSecrets }}
  imagePullSecrets:
    - name: {{ $service.imagePullSecrets }}
  {{- end -}}
  {{- if $service.serviceAccountName }}
  serviceAccountName: {{ $service.serviceAccountName }}
  {{- end -}}
  {{- if get $restartPolicyMap (get $restartPolicy "condition") }}
  restartPolicy: {{ get $restartPolicyMap (get $restartPolicy "condition") }}
  {{- end -}}
{{- end -}}


{{- define "stack.deployment" -}}
{{-   $name := .name | replace "_" "-" -}}
{{-   $kind := .kind -}}
{{-   $service := .service -}}
{{-   $replicas := $service | pluck "deploy"| first | default dict | pluck "replicas" | first -}}
{{-   $volumes := include "stack.helpers.volumes" (dict "Values" .Values) | fromYaml -}}
{{-   $configs := include "stack.helpers.configs" (dict "Values" .Values) | fromYaml -}}
{{-   $secrets := include "stack.helpers.secrets" (dict "Values" .Values) | fromYaml -}}
{{-   $volumeClaimTemplates := dict -}}
{{-   $placement := $service | pluck "deploy" | first | default dict | pluck "placement" | first | default dict -}}
{{-   $restartPolicy := . | pluck "service" | first | default dict | pluck "deploy" | first | default dict | pluck "restart_policy" | first | default dict -}}
{{-   $containers := omit $service "containers" | prepend ($service.containers | default list) -}}
{{-   $initContainers := $service.initContainers | default list -}}
{{-   range $container := (concat $containers $initContainers) -}}
{{-     range $mount := $container.volumes -}}
{{-       $mountOptions := include "stack.helpers.normalizeVolumeMount" $mount | fromYaml -}}
{{-       $volName := $mountOptions.source | replace "_" "-" -}}
{{-       if not (or (hasPrefix "/" $volName) (hasPrefix "./" $volName)) -}}
{{-         $curr := get $volumes $volName | deepCopy -}}
{{-         if and (eq $kind "StatefulSet") (ne $curr.type "emptyDir") (not $curr.external) (get $curr "dynamic") -}}
{{-           $_ := set $volumeClaimTemplates $volName $curr -}}
{{-         end -}}
{{-       end -}}
{{-     end -}}
{{-   end -}}
{{- $podSpec := include "stack.helpers.podSpec" (dict "name" $name "kind" $kind "service" $service "volumes" $volumes "configs" $configs "secrets" $secrets "containers" $containers "initContainers" $initContainers "placement" $placement "restartPolicy" $restartPolicy "Values" .Values) | fromYaml -}}
{{- /* Job */ -}}
{{- if eq $kind "Job" -}}
apiVersion: batch/v1
kind: {{ $kind }}
metadata:
  name: {{ $name | quote }}
spec:
  template:
    {{ mergeOverwrite (dict "spec" (dict "restartPolicy" "Never")) $podSpec | toYaml | nindent 4 }}
{{- /* CronJob */ -}}
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
        {{ mergeOverwrite (dict "spec" (dict "restartPolicy" "Never")) $podSpec | toYaml | nindent 8 }}
{{- /* Deployment, StatefulSet, DaemonSet */ -}}
{{- else -}}
apiVersion: apps/v1
kind: {{ $kind }}
metadata:
  name: {{ $name | quote }}
spec:
  {{- if and (ne $kind "DaemonSet") $replicas }}
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
      spec: {{ get $pvc "spec" | toYaml | nindent 8 }}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

