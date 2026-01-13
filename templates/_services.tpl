{{- define "stack.service.loadBalancer" -}}
{{-   $name := .name | replace "_" "-" -}}
{{-   $ports := .ports -}}
{{- if $ports -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ printf "%s-loadbalancer" $name | quote }}
spec:
  type: LoadBalancer
  ports:
    {{- range $ports }}
    - name: {{ printf "%s-%s" (get . "protocol") (get . "port") | lower | quote }}
      protocol: {{ get . "protocol" | quote }}
      port: {{ get . "port" }}
      targetPort: {{ get . "targetPort" }}
    {{- end }}
  selector:
    service: {{ $name | quote }}
{{- end -}}
{{- end -}}


{{- define "stack.service.clusterIP" -}}
{{-   $name := .name | replace "_" "-" -}}
{{-   $service := .service -}}
{{-   $ports := get (include "stack.helpers.normalizePorts" ($service.expose | default dict) | fromYaml) "all" -}}
{{-   $labels := $service | pluck "deploy" | first | default dict | pluck "labels" | first | default list -}}
{{-   $port := "" -}}
{{-   range $labelName, $labelValue := include "stack.helpers.normalizeKV" $labels | fromYaml -}}
{{-     if regexMatch "^traefik\\.(\\w+\\.)?port$" $labelName -}}
{{-       $port = $labelValue -}}
{{-       $existed := false -}}
{{-       range $ports -}}
{{-         if eq (get . "targetPort") $port -}}
{{-           $existed = true -}}
{{-         end -}}
{{-       end -}}
{{-       if not $existed -}}
{{-         $ports = append $ports (dict "protocol" "TCP" "port" $port "targetPort" $port) -}}
{{-       end -}}
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
    - name: {{ printf "%s-%s" (get . "protocol") (get . "port") | lower | quote }}
      protocol: {{ get . "protocol" | quote }}
      port: {{ get . "port" }}
      targetPort: {{ get . "targetPort" }}
    {{- end }}
  selector:
    service: {{ $name | quote }}
{{- end -}}
{{- end -}}


{{- define "stack.service.nodePort" -}}
{{-   $name := .name | replace "_" "-" -}}
{{-   $service := .service -}}
{{-   $ports := get (include "stack.helpers.normalizePorts" ($service.nodePorts | default dict) | fromYaml) "all" -}}
{{- if $ports -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ printf "%s-nodeport" $name | quote }}
spec:
  type: NodePort
  ports:
    {{- range $ports }}
    - name: {{ printf "%s-%s" (get . "protocol") (get . "port") | lower | quote }}
      protocol: {{ get . "protocol" | quote }}
      port: {{ get . "targetPort" }}
      targetPort: {{ get . "targetPort" }}
      {{- if get . "port" }}
      nodePort: {{ get . "port" }}
      {{- end -}}
    {{- end }}
  selector:
    service: {{ $name | quote }}
{{- end -}}
{{- end -}}