package rr_plugin

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
)

type Verifier struct {
	Keys    [][]byte
	Salts   [][]byte
	Enabled bool
}

func (v *Verifier) SetPairs(rawKeys string, rawSalts string) error {
	if rawKeys == "" {
		return fmt.Errorf("key is empty")
	}

	if rawSalts == "" {
		return fmt.Errorf("salt is empty")
	}

	keys := strings.Split(rawKeys, ",")
	salts := strings.Split(rawSalts, ",")

	pairsNum := min(len(keys), len(salts))

	v.Keys = make([][]byte, pairsNum)
	v.Salts = make([][]byte, pairsNum)

	var err error

	for i := 0; i < pairsNum; i++ {
		if v.Keys[i], err = hex.DecodeString(keys[i]); err != nil {
			return fmt.Errorf("key[%d] must be a hex-encoded string", i)
		}

		if v.Salts[i], err = hex.DecodeString(salts[i]); err != nil {
			return fmt.Errorf("salt[%d] must be a hex-encoded string", i)
		}
	}

	v.Enabled = true

	return nil
}

func (v *Verifier) Verify(signature string, subject string) error {
	providedSignature, err := base64.RawURLEncoding.DecodeString(signature)
	if err != nil {
		return errors.New("invalid signature encoding")
	}

	for i, key := range v.Keys {
		h := hmac.New(sha256.New, key)
		h.Write(v.Salts[i])
		h.Write([]byte(subject))
		expectedSignature := h.Sum(nil)

		if hmac.Equal(expectedSignature, providedSignature) {
			return nil
		}
	}

	return errors.New("signature mismatch")
}
