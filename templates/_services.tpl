{{- define "stack.service.loadBalancer" -}}
{{-   $name := .name -}}
{{-   $protocol := .protocol -}}
{{-   $ports := .ports -}}
{{ if $ports }}
apiVersion: v1
kind: Service
metadata:
  name: {{ printf "%s-loadbalancer-%s" $name $protocol | replace "_" "-" | quote }}
spec:
  type: LoadBalancer
  ports:
    {{- range $ports }}
    - name: {{ printf "loadbalancer-%s" (get . "port") | lower | quote }}
      protocol: {{ get . "protocol" | quote }}
      port: {{ get . "port" }}
      targetPort: {{ get . "targetPort" }}
    {{- end }}
  selector:
    service: {{ $name | quote }}
{{- end -}}
{{- end -}}


{{- define "stack.service.clusterIP" -}}
{{-   $name := .name -}}
{{-   $service := .service -}}
{{-   $ports := list -}}
{{-   if $service.ClusterIP -}}
{{-     $ports = get (include "stack.helpers.normalizePorts" $service.ClusterIP.ports | fromYaml) "all" -}}
{{-   end -}}
{{-   $labels := $service | pluck "deploy" | first | default dict | pluck "labels" | first | default list -}}
{{-   $port := "" -}}
{{-   range $labelName, $labelValue := include "stack.helpers.normalizeKV" $labels | fromYaml -}}
{{-     if eq $labelName "traefik.port" -}}
{{-       $port = $labelValue -}}
{{-     end -}}
{{-   end -}}
{{-   if $port -}}
{{-     $existed := false -}}
{{-     range $ports -}}
{{-       if eq (get . "port") $port -}}
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
  name: {{ printf "%s" $name | replace "_" "-" | quote }}
spec:
  type: ClusterIP
  ports:
    {{- range $ports }}
    - name: {{ printf "clusterip-%s" (get . "port") | lower | quote }}
      protocol: {{ get . "protocol" | quote }}
      port: {{ get . "port" }}
      targetPort: {{ get . "targetPort" }}
    {{- end }}
  selector:
    service: {{ $name | replace "_" "-" | quote }}
{{- end -}}
{{- end -}}


{{- define "stack.service.nodePort" -}}
{{-   $name := .name -}}
{{-   $service := .service -}}
{{-   $ports := list -}}
{{-   if $service.NodePort -}}
{{-     $ports = get (include "stack.helpers.normalizePorts" $service.NodePort.ports | fromYaml) "all" -}}
{{-   end -}}
{{- if $ports -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ printf "%s-nodeport" $name | replace "_" "-" | quote }}
spec:
  type: NodePort
  ports:
    {{- range $ports }}
    - name: {{ printf "nodeport-%s" (get . "port") | lower | quote }}
      protocol: {{ get . "protocol" | quote }}
      port: {{ get . "targetPort" }}
      targetPort: {{ get . "targetPort" }}
      {{- if get . "port" }}
      nodePort: {{ get . "port" }}
      {{- end }}
    {{- end }}
  selector:
    service: {{ $name | replace "_" "-" | quote }}
{{- end -}}
{{- end -}}