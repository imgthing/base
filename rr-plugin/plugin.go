package rr_plugin

import (
	"github.com/roadrunner-server/http/v5/attributes"
	"go.uber.org/zap"
	"net/http"
	"regexp"
)

const name = "imgthing"

type Configurer interface {
	UnmarshalKey(name string, out any) error
	Has(name string) bool
}

type Logger interface {
	NamedLogger(name string) *zap.Logger
}

type Plugin struct {
	log      *zap.Logger
	cfg      Config
	verifier Verifier
}

func (p *Plugin) Init(cfg Configurer, logger Logger) error {
	p.log = logger.NamedLogger(name)
	p.verifier = Verifier{}
	cfg.UnmarshalKey(name, &p.cfg)

	if err := p.verifier.SetPairs(p.cfg.Key, p.cfg.Salt); err != nil {
		p.log.Warn("Signature validation disabled", zap.String("reason", err.Error()))
	}

	return nil
}

func (p *Plugin) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "GET" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		signedPath := r.URL.EscapedPath()

		re := regexp.MustCompile(`^/(\w{1,32})/`)
		matches := re.FindStringSubmatch(signedPath)

		if len(matches) != 2 {
			http.Error(w, "Signature missing", http.StatusBadRequest)
			return
		}

		signature := matches[1]
		unsignedPath := signedPath[len(signature)+1:]

		if p.verifier.Enabled {
			var subject string

			if p.cfg.DomainAware {
				subject = r.Host + unsignedPath
			} else {
				subject = unsignedPath
			}

			p.log.Info("v", zap.String("subject", subject), zap.String("signature", signature))

			if err := p.verifier.Verify(signature, subject); err != nil {
				http.Error(w, "Malformed signature", http.StatusBadRequest)
				return
			}
		}

		r = attributes.Init(r)
		_ = attributes.Set(r, "unsigned_path", unsignedPath)

		next.ServeHTTP(w, r)
	})
}

func (p *Plugin) RPC() any {
	return &RPC{plugin: p, log: p.log}
}

func (p *Plugin) Name() string {

	return name
}
