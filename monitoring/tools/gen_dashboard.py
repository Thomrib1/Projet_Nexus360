#!/usr/bin/env python3
"""Génère le tableau de bord Grafana « Nexus360 — État du site » (une page).
Usage : python3 tools/gen_dashboard.py  (réécrit ansible/roles/mon/files/dashboards/...)"""
import json, pathlib

DS = {"type": "prometheus", "uid": "prometheus"}
pid = 0
def panel(kind, title, x, y, w, h, targets, **extra):
    global pid; pid += 1
    p = {"id": pid, "type": kind, "title": title, "datasource": DS,
         "gridPos": {"x": x, "y": y, "w": w, "h": h},
         "targets": [dict(refId=chr(65+i), datasource=DS, **t) for i, t in enumerate(targets)]}
    p.update(extra); return p

def thresholds(*steps):
    return {"mode": "absolute", "steps": [{"color": c, "value": v} for v, c in steps]}

UPDOWN = [{"type": "value", "options": {
    "0": {"text": "PANNE", "color": "red", "index": 0},
    "1": {"text": "OK", "color": "green", "index": 1}}}]

panels = [
  panel("stat", "Serveurs en ligne", 0, 0, 4, 4,
        [{"expr": 'sum(up{job=~"linux|windows"})', "instant": True}],
        fieldConfig={"defaults": {"unit": "none", "thresholds": thresholds((None, "red"), (7, "green"))}, "overrides": []},
        options={"colorMode": "background", "reduceOptions": {"calcs": ["lastNotNull"]}, "textMode": "value"},
        description="Nombre de machines dont l'agent répond (objectif : 7 serveurs + passerelles)."),
  panel("stat", "Alertes en cours", 4, 0, 4, 4,
        [{"expr": 'count(ALERTS{alertstate="firing"}) or vector(0)', "instant": True}],
        fieldConfig={"defaults": {"thresholds": thresholds((None, "green"), (1, "red"))}, "overrides": []},
        options={"colorMode": "background", "reduceOptions": {"calcs": ["lastNotNull"]}}),
  panel("stat", "Intranet (service rendu)", 8, 0, 4, 4,
        [{"expr": 'min(probe_success{job="blackbox_http"})', "instant": True}],
        fieldConfig={"defaults": {"mappings": UPDOWN, "thresholds": thresholds((None, "red"), (1, "green"))}, "overrides": []},
        options={"colorMode": "background", "reduceOptions": {"calcs": ["lastNotNull"]}}),
  panel("stat", "Sauvegarde la plus ancienne", 12, 0, 6, 4,
        [{"expr": 'max(time() - nexus_backup_last_success_timestamp_seconds)', "instant": True}],
        fieldConfig={"defaults": {"unit": "s", "thresholds": thresholds((None, "green"), (93600, "red"))}, "overrides": []},
        options={"colorMode": "background", "reduceOptions": {"calcs": ["lastNotNull"]}},
        description="Âge de la plus vieille 'dernière sauvegarde réussie' (rouge au-delà de 26 h)."),
  panel("stat", "RAID LNX-OPS01", 18, 0, 6, 4,
        [{"expr": 'max(node_md_disks_required - ignoring(state) node_md_disks{state="active"}) or vector(0)', "instant": True}],
        fieldConfig={"defaults": {"mappings": [{"type": "value", "options": {"0": {"text": "MIROIR OK", "color": "green"}}},
                                                {"type": "range", "options": {"from": 1, "to": 99, "result": {"text": "DÉGRADÉ", "color": "red"}}}],
                                  "thresholds": thresholds((None, "green"), (1, "red"))}, "overrides": []},
        options={"colorMode": "background", "reduceOptions": {"calcs": ["lastNotNull"]}}),

  panel("stat", "État des serveurs", 0, 4, 24, 4,
        [{"expr": 'up{job=~"linux|windows"}', "legendFormat": "{{instance}}", "instant": True}],
        fieldConfig={"defaults": {"mappings": UPDOWN, "thresholds": thresholds((None, "red"), (1, "green"))}, "overrides": []},
        options={"colorMode": "background", "textMode": "value_and_name", "orientation": "vertical",
                 "reduceOptions": {"calcs": ["lastNotNull"]}}),

  panel("stat", "Services Windows critiques", 0, 8, 14, 5,
        [{"expr": 'windows_service_state{state="running"}', "legendFormat": "{{instance}} · {{name}}", "instant": True}],
        fieldConfig={"defaults": {"mappings": UPDOWN, "thresholds": thresholds((None, "red"), (1, "green"))}, "overrides": []},
        options={"colorMode": "background", "textMode": "value_and_name", "reduceOptions": {"calcs": ["lastNotNull"]}}),
  panel("stat", "Sondes infra (LDAP, SMB, DNS)", 14, 8, 10, 5,
        [{"expr": 'probe_success{job=~"blackbox_tcp|blackbox_dns"}', "legendFormat": "{{job}} · {{instance}}", "instant": True}],
        fieldConfig={"defaults": {"mappings": UPDOWN, "thresholds": thresholds((None, "red"), (1, "green"))}, "overrides": []},
        options={"colorMode": "background", "textMode": "value_and_name", "reduceOptions": {"calcs": ["lastNotNull"]}}),

  panel("timeseries", "CPU (%)", 0, 13, 8, 7, [
        {"expr": '100 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100', "legendFormat": "{{instance}}"},
        {"expr": '100 - avg by (instance) (rate(windows_cpu_time_total{mode="idle"}[2m])) * 100', "legendFormat": "{{instance}}"}],
        fieldConfig={"defaults": {"unit": "percent", "min": 0, "max": 100}, "overrides": []},
        options={"legend": {"displayMode": "list", "placement": "bottom"}}),
  panel("timeseries", "Mémoire utilisée (%)", 8, 13, 8, 7, [
        {"expr": '(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100', "legendFormat": "{{instance}}"},
        {"expr": '(1 - windows_memory_physical_free_bytes / windows_memory_physical_total_bytes) * 100', "legendFormat": "{{instance}}"}],
        fieldConfig={"defaults": {"unit": "percent", "min": 0, "max": 100}, "overrides": []},
        options={"legend": {"displayMode": "list", "placement": "bottom"}}),
  panel("bargauge", "Disques les plus remplis (%)", 16, 13, 8, 7, [
        {"expr": 'topk(8, (1 - node_filesystem_avail_bytes{fstype=~"xfs|ext4"} / node_filesystem_size_bytes{fstype=~"xfs|ext4"}) * 100)',
         "legendFormat": "{{instance}} {{mountpoint}}", "instant": True},
        {"expr": 'topk(4, (1 - windows_logical_disk_free_bytes{volume!~"HarddiskVolume.*"} / windows_logical_disk_size_bytes{volume!~"HarddiskVolume.*"}) * 100)',
         "legendFormat": "{{instance}} {{volume}}", "instant": True}],
        fieldConfig={"defaults": {"unit": "percent", "min": 0, "max": 100,
                                  "thresholds": thresholds((None, "green"), (75, "orange"), (85, "red"))}, "overrides": []},
        options={"orientation": "horizontal", "displayMode": "gradient", "reduceOptions": {"calcs": ["lastNotNull"]}}),

  panel("table", "Alertes actives (détail)", 0, 20, 24, 6,
        [{"expr": 'ALERTS{alertstate="firing"}', "format": "table", "instant": True}],
        transformations=[{"id": "organize", "options": {
            "excludeByName": {"Time": True, "Value": True, "__name__": True, "alertstate": True},
            "indexByName": {"severity": 0, "alertname": 1, "instance": 2}}}],
        fieldConfig={"defaults": {}, "overrides": [{"matcher": {"id": "byName", "options": "severity"},
            "properties": [{"id": "custom.cellOptions", "value": {"type": "color-background"}},
                           {"id": "mappings", "value": [{"type": "value", "options": {
                               "critical": {"color": "red", "index": 0}, "warning": {"color": "orange", "index": 1}}}]}]}]}),
]

dash = {
  "uid": "nexus360-site", "title": "Nexus360 — État du site de Paris",
  "tags": ["nexus360", "exploitation"], "timezone": "browser", "editable": False,
  "refresh": "30s", "time": {"from": "now-3h", "to": "now"}, "schemaVersion": 39, "version": 1,
  "annotations": {"list": [
      {"builtIn": 1, "datasource": {"type": "grafana", "uid": "-- Grafana --"}, "enable": True,
       "hide": False, "iconColor": "rgba(0, 211, 255, 1)", "name": "Déploiements (pipeline)", "type": "dashboard"}]},
  "panels": panels,
}
out = pathlib.Path(__file__).resolve().parent.parent / "ansible/roles/mon/files/dashboards/nexus360-etat-du-site.json"
out.write_text(json.dumps(dash, indent=2, ensure_ascii=False) + "\n")
print(f"écrit : {out} ({len(panels)} panneaux)")
