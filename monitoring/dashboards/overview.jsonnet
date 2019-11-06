local grafana = import "grafana.libsonnet";

// Map from service to regex of matching roles.
// Role explanations:
//  replica: Just downloads and replicates segments
//  local_edit: Also runs a local thrimbletrimmer for doing local cuts
//  edit: Also runs cutter for doing uploads
//  leader: Also runs things that only run in one place, eg. sheetsync
local roles_for_service = {
  "restreamer": ".*",
  "downloader": ".*",
  "backfiller": ".*",
  "segment_coverage": ".*",
  "thrimshim": "leader|edit|local_edit",
  "cutter": "leader|edit",
  "sheetsync": "leader",
};

// List of services, to impart ordering
local services = [
  "restreamer",
  "downloader",
  "backfiller",
  "segment_coverage",
  "thrimshim",
  "cutter",
  "sheetsync",
];

local service_status_table = {
  local refId(n) = std.char(std.codepoint('A') + n),
  type: "table",
  targets: [
    {
      expr: 'sum(up{job="%s", role=~"%s"}) by (instance)' % [services[i], roles_for_service[services[i]]],
      intervalFactor: 1,
      format: "table",
      refId: refId(i),
      legendFormat: "",
      instant: true,
    }
    for i in std.range(0, std.length(services) - 1)
  ],
  styles: [
    // hidden cols
    {
      unit: "short",
      type: "hidden",
      alias: "",
      decimals: 2,
      colors: [
        "rgba(245, 54, 54, 0.9)",
        "rgba(237, 129, 40, 0.89)",
        "rgba(50, 172, 45, 0.97)",
      ],
      colorMode: null,
      pattern: name,
      dateFormat: "YYYY-MM-DD HH:mm:ss",
      thresholds: [],
      mappingType: 1,
    }
    for name in ["__name__", "job", "Time"]
  ] + [
    // service cols
    {
      unit: "short",
      type: "string",
      alias: services[i],
      decimals: 2,
      colors: [
        "rgba(245, 54, 54, 0.9)",
        "rgba(237, 129, 40, 0.89)",
        "rgba(50, 172, 45, 0.97)",
      ],
      colorMode: "cell",
      pattern: "Value #%s" % refId(i),
      dateFormat: "YYYY-MM-DD HH:mm:ss",
      thresholds: [
        "0.5",
        "0.5",
      ],
      mappingType: 1,
      valueMaps: [
        {
          value: "0",
          text: "DOWN",
        },
        {
          value: "1",
          text: "UP",
        },
      ],
    } for i in std.range(0, std.length(services) - 1)
  ],
  transform: "table",
  pageSize: null,
  showHeader: true,
  columns: [],
  scroll: true,
  fontSize: "100%",
  sort: {col: 1, desc: false}, // sort by instance
  links: [],
};

grafana.dashboard({
  name: "Overview",
  uid: "rjd405mn",

  rows: [

    {
      panels: [
        // First row - immediate status heads-up
        [
          {
            name: "Service Status by Node",
            span: 2 * grafana.span.third,
            custom: service_status_table,
          },
          {
            name: "Error log rate",
            axis: {min: 0, label: "logs / sec"},
            display: "bars",
            expressions: {
              "{{instance}} {{job}} {{level}}({{module}}:{{function}})": |||
                sum(irate(log_count_total{level!="INFO"}[2m])) by (instance, job, level, module, function) > 0
              |||,
            },
          },
        ],
        // Second row - core "business" metrics
        [
          {
            name: "Segments downloaded",
            axis: {min: 0, label: "segments / sec"},
            expressions: {
              "{{channel}}({{quality}}) live capture":
                'sum(rate(segments_downloaded_total[2m])) by (channel, quality)',
              "{{channel}}({{quality}}) backfilled":
                'sum(rate(segments_backfilled_total[2m])) by (channel, quality)',
            },
          },
          {
            name: "Successful requests by endpoint",
            axis: {min: 0, label: "requests / sec"},
            expressions: {
              "{{method}} {{endpoint}}":
                'sum(rate(http_request_latency_all_count{status="200"}[2m])) by (endpoint, method)',
            },
          },
          {
            name: "Database events by state",
            axis: {min: 0, label: "events"},
            tooltip: "Not implemented", // TODO
            expressions: {"Not implemented": "0"},
          },
        ],
      ],
    },

    {
      name: "Downloader",
      panels: [
        {
          name: "Segments downloaded by node",
          axis: {min: 0, label: "segments / sec"},
          expressions: {
            "{{instance}} {{channel}}({{quality}})":
              'sum(rate(segments_downloaded_total[2m])) by (instance, channel, quality)',
          },
        },
        {
          name: "Downloader stream delay by node",
          tooltip: "Time between the latest downloaded segment's timestamp and current time",
          axis: {min: 0, format: grafana.formats.time},
          expressions: {
            "{{instance}} {{channel}}({{quality}})":
              // Ignore series where we're no longer fetching segments,
              // as they just show that it's been a long time since the last segment.
              |||
                time() - max(latest_segment) by (instance, channel, quality)
                and sum(irate(segments_downloaded_total[2m])) by (instance, channel, quality) > 0
              |||,
          },
        },
      ],
    },

    {
      name: "Backfiller",
      panels: [
        {
          name: "Backfill by node pair",
          axis: {min: 0, label: "segments / sec"},
          expressions: {
            "{{remote}} -> {{instance}}":
              'sum(rate(segments_backfilled_total[2m])) by (remote, instance)',
          },
        },
      ],
    },

  ],

})
