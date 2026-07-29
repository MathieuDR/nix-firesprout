# Single wildcard vhost for every *.home.deraedt.dev service. One DNS-01 challenge
# (_acme-challenge.home.deraedt.dev) and one cert for all of them, so adding a service
# no longer triggers a per-subdomain challenge (which kept orphaning ACME TXT records).
#
# Rollout is two-phase: this vhost is added first *alongside* the per-service vhosts
# (Caddy prefers the more-specific site, so routing is unchanged and this just obtains
# the wildcard cert); once that cert is confirmed, the per-service .home vhosts are
# removed and this takes over.
{...}: {
  services.caddy.virtualHosts."*.home.deraedt.dev".extraConfig = ''
    encode {
      zstd
      gzip
      minimum_length 1024
    }

    @immich host pics.home.deraedt.dev
    handle @immich {
      reverse_proxy http://localhost:2283 # immich listens on [::1] only
    }

    # paperless: large-upload timeout route first, then the general route
    @paperless_upload {
      host docs.home.deraedt.dev
      path /api/documents/post_document*
    }
    handle @paperless_upload {
      reverse_proxy http://127.0.0.1:29818 {
        transport http {
          read_timeout 300s
          write_timeout 300s
        }
      }
    }
    @paperless host docs.home.deraedt.dev
    handle @paperless {
      header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "strict-origin-when-cross-origin"
      }
      reverse_proxy http://127.0.0.1:29818
    }

    @actual host actual.home.deraedt.dev
    handle @actual {
      reverse_proxy http://127.0.0.1:5006
    }

    @mealie host recipes.home.deraedt.dev
    handle @mealie {
      reverse_proxy http://127.0.0.1:9099
    }

    @ntfy host ntfy.home.deraedt.dev
    handle @ntfy {
      reverse_proxy http://127.0.0.1:2586
    }

    @status host status.home.deraedt.dev
    handle @status {
      reverse_proxy http://127.0.0.1:8095
    }

    @metrics host metrics.home.deraedt.dev
    handle @metrics {
      reverse_proxy http://127.0.0.1:8090
    }

    handle {
      respond "unknown home service" 404
    }
  '';
}
