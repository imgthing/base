package rr_plugin

type Config struct {
	Salt        string `mapstructure:"salt"`
	Key         string `mapstructure:"key"`
	DomainAware bool   `mapstructure:"domain_aware"`
}
