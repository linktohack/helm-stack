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
Affinities from constraints
Result is a dict { "data": $affinities }
*/}}
{{- define "stack.helpers.affinitiesFromConstraints" -}}
{{-     $constraint := . -}}
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
key: node-role.kubernetes.io/master
operator: {{ $op }}
values: [{{ $val }}]
{{-       end -}}
{{-       if eq $first "node.hostname" -}}
key: kubernetes.io/hostname
operator: {{ $op }}
values: [{{ $last }}]
{{-       end -}}
{{-       if hasPrefix "node.labels" $first -}}
key: {{ replace "node.labels." ""  $first }}
operator: {{ $op }}
values: [{{ $last }}]
{{-       end -}}
{{-     end -}}
{{-     if (eq $op "Exists") -}}
{{-       if hasPrefix "node.labels" $constraint -}}
key: {{ replace "node.labels." "" $constraint }}
operator: {{ $op }}
{{-       end -}}
{{-     end -}}
{{- end -}}

{{- define "stack.helpers.tolerations" }}
{{-   if not (eq (typeOf .) "string") }}
{{-     fail "deploy.placement.tolerations[] must be string" }}
{{-   end }}
{{-   if not (regexMatch "^([^=:]+(=[^=:]+)?)?:(NoSchedule|PreferNoSchedule|NoExecute)$" .) }}
{{-     fail "deploy.placement.tolerations[] must be [key[=value]]:(NoSchedule|PreferNoSchedule|NoExecute)"}}
{{-   end }}
{{-   $tokens := splitList ":" . }}
{{-   $effect := index $tokens 1 }}
{{-   $pair := index $tokens 0 | splitList "=" }}
effect: {{ $effect }}
{{-   if index $pair 0 }}
key: {{ index $pair 0 }}
{{-   end }}
{{-   if lt (len $pair) 2 }}
operator: Exists
{{-   else }}
operator: Equal
value: {{ index $pair 1 }}
{{-   end }}
{{- end }}

{{- define "stack.helpers.podSpec" }}
{{-   $name := .name | replace "_" "-" }}
{{-   $service := .service }}
{{-   $containers := .containers }}
{{-   $initContainers := .initContainers }}
{{-   $placement := .placement }}
{{-   $restartPolicy := .restartPolicy }}
{{-   $podVolumes := .podVolumes -}}
{{-   $restartPolicyMap := dict "" "" "none" "Never" "on-failure" "OnFailure" "any" "Always" -}}
spec:
  {{- $affinities := $placement.constraints }}
  {{- if $affinities }}
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
            {{- range $expression := $affinities }}
            - {{ include "stack.helpers.affinitiesFromConstraints" $expression | indent 14 | trim }}
            {{- end }}
  {{- end }}

  {{- $tolerations := $placement.tolerations }}
  {{- if $tolerations }}
  tolerations:
  {{- range $toleration := $service.deploy.placement.tolerations }}
  - {{ include "stack.helpers.tolerations" $toleration | indent 4 | trim }}
  {{- end }}
  {{- end }}

  {{- if $service.dns }}
  dnsPolicy: "None"
  dnsConfig:
    nameservers: {{ $service.dns | toYaml | nindent 10 }}
  {{- end }}

  containers:
  {{- range $index, $container := $containers }}
  {{-   $params := dict "index" $index "container" $container "name" $name }}
  {{-   $value := include "stack.helpers.container" $params | fromYaml }}
  - {{  include "stack.helpers.containerSpec" $value | nindent 4 | trim }}
  {{- end }}

  {{- if $initContainers }}
  initContainers:
  {{- range $index, $container := $initContainers }}
  {{-   $params := dict "index" $index "container" $container "name" (printf "%s-init" $name) }}
  {{-   $value := include "stack.helpers.container" $params | fromYaml }}
  - {{  include "stack.helpers.containerSpec" $value | nindent 4 | trim }}
  {{- end }}
  {{- end }}

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
        name: {{ $volName | quote }}
        {{/* if there's configs mount with .mode */}}
        {{- if values $volValue.items | compact }}
        items:
        {{- range $key, $mode := $volValue.items }}
        - key: {{ $key }}
          path: {{ $key }}
          {{- if $mode }}
          mode: {{ $mode }}
          {{- end }}
        {{- end }}
        {{- end }}
    {{- end }}
    {{- if eq $volValue.volumeKind "Secret" }}
      secret:
        secretName: {{ $volName | quote }}
        {{/* if there's secrets mount with .mode */}}
        {{- if values $volValue.items | compact }}
        items:
        {{- range $key, $mode := $volValue.items }}
        - key: {{ $key }}
          path: {{ $key }}
          {{- if $mode }}
          mode: {{ $mode }}
          {{- end }}
        {{- end }}
        {{- end }}
    {{- end }}
  {{- end }}
  {{- end }}

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
{{-   $chdir := .Values.chdir -}}
{{-   $service := .service -}}
{{-   $replicas := $service | pluck "deploy"| first | default dict | pluck "replicas" | first -}}
{{-   $volumes := include "stack.helpers.volumes" (dict "Values" .Values) | fromYaml -}}
{{-   $configs := .configs -}}
{{-   $secrets := .secrets -}}
{{-   $placement := include "getPath" (list $service "deploy.placement") | fromYaml | default dict -}}
{{-   $restartPolicy := . | pluck "service" | first | default dict | pluck "deploy" | first | default dict | pluck "restart_policy" | first | default dict -}}
{{-   $containers := omit $service "containers" | prepend ($service.containers | default list) -}}
{{-   $initContainers := $service.initContainers | default list -}}
{{-   $podVolumes := dict -}}
{{-   $podHostpaths := dict -}}
{{-   $volumeClaimTemplates := dict -}}

{{/* Preprocess .volumes for StatefulSet, Pod, Container */}}
{{-   range $container := (concat $containers $initContainers) -}}
{{-     $volumeMounts := list -}}
{{-     range $mount := $container.volumes -}}
{{-       $mountOptions := include "stack.helpers.volumeMountOptions" $mount | fromYaml -}}
{{/* Fix relative path first */}}
{{-       if hasPrefix "./" $mountOptions.source -}}
{{-         $src := clean (printf "%s/%s" (default "." $chdir) $mountOptions.source) -}}
{{-         if not (isAbs $src) -}}
{{-           fail (printf "volume path or chdir has to be absolute: %s" $src) -}}
{{-         end -}}
{{-         $_ := set $mountOptions "source" $src -}}
{{-       end -}}
{{/* Hostpath */}}
{{-       if hasPrefix "/" $mountOptions.source -}}
{{-         $key := $mountOptions.source -}}
{{-         $defaultName := printf "hostpath-%d" (len $podHostpaths) -}}
{{-         $hostpath := get $podHostpaths $key | default (dict "name" $defaultName "volumeKind" "Volume" "type" "hostPath") -}}
{{-         $_ := merge $mountOptions $hostpath -}}
{{-         $_ := set $podHostpaths $key $mountOptions -}}
{{/* PersistentVolumeClaim */}}
{{-       else -}}
{{-         $name := $mountOptions.source | replace "_" "-" -}}
{{-         $_ := merge $mountOptions (dict "name" $name "volumeKind" "Volume") (get $volumes $name) -}}
{{-         with $mountOptions -}}
{{-           if and (eq $kind "StatefulSet") (ne .type "emptyDir") (not .external) .dynamic -}}
{{-             $_ := set $volumeClaimTemplates $name . -}}
{{-           else -}}
{{-             $_ := set $podVolumes $name . -}}
{{-           end -}}
{{-         end -}}
{{-       end -}}
{{-       $volumeMounts = append $volumeMounts $mountOptions -}}
{{-     end -}}
{{- /* CONFIG */ -}}
{{-     range $volValue := $container.configs -}}
{{-       $mount := include "stack.helpers.configMountOptions" $volValue | fromYaml -}}
{{-       $config := get $configs $mount.source -}}
{{-       if not $config -}}
{{-         fail (printf "Could not find config `%s` to mount" $mount.source) -}}
{{-       end -}}
{{-       $volume := merge (dict "volumeKind" "ConfigMap") $mount $config -}}
{{-       $volumeMounts = append $volumeMounts $volume -}}
{{-       $podVolume := get $podVolumes $volume.name | default (dict "volumeKind" "ConfigMap" "name" $volume.name "items" dict) -}}
{{-       $_ := set $podVolume.items $volume.source $volume.mode -}}
{{-       $_ := set $podVolumes $volume.name $podVolume -}}
{{-     end -}}
{{- /* SECRET: copy of CONFIG */ -}}
{{-     range $volValue := $container.secrets -}}
{{-       $mount := include "stack.helpers.secretMountOptions" $volValue | fromYaml -}}
{{-       $secret := get $secrets $mount.source -}}
{{-       if not $secret -}}
{{-         fail (printf "Could not find secret `%s` to mount" $mount.source) -}}
{{-       end -}}
{{-       $volume := merge (dict "volumeKind" "Secret") $mount $secret -}}
{{-       $volumeMounts = append $volumeMounts $volume -}}
{{-       $podVolume := get $podVolumes $volume.name | default (dict "volumeKind" "Secret" "name" $volume.name "items" dict) -}}
{{-       $_ := set $podVolume.items $volume.source $volume.mode -}}
{{-       $_ := set $podVolumes $volume.name $podVolume -}}
{{-     end -}}
{{-     $_ := set $container "volumeMounts" $volumeMounts -}}
{{-   end -}}
{{- $podSpec := include "stack.helpers.podSpec" (dict "name" $name "service" $service "containers" $containers "initContainers" $initContainers "placement" $placement "restartPolicy" $restartPolicy "podVolumes" (merge $podVolumes $podHostpaths)) | fromYaml -}}

{{- if eq $kind "Job" -}}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ $name | quote }}
spec:
  template:
    {{ mergeOverwrite (dict "spec" (dict "restartPolicy" "Never")) $podSpec | toYaml | nindent 4 }}

{{- else if eq $kind "CronJob" -}}
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: {{ $name | quote }}
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        {{ mergeOverwrite (dict "spec" (dict "restartPolicy" "Never")) $podSpec | toYaml | nindent 8 }}

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

