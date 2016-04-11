package codesearch

import (
	"bytes"
	"fmt"
	"log"
)

var _ = log.Printf

type SuggestQueryError struct {
	Message    string
	Suggestion string
}

func (e *SuggestQueryError) Error() string {
	return fmt.Sprintf("%s. Suggestion: %s", e.Message, e.Suggestion)
}

func parseStringLiteral(in []byte) (lit []byte, n int, err error) {
	left := in[1:]
	found := false
	for len(left) > 0 {
		c := left[0]
		left = left[1:]
		switch c {
		case '"':
			found = true
			break
		case '\\':
			// TODO - other escape sequences.
			if len(left) == 0 {
				return nil, 0, fmt.Errorf("missing char after \\")
			}
			c = left[0]
			left = left[1:]

			lit = append(lit, c)
		default:
			lit = append(lit, c)
		}
	}
	if !found {
		return nil, 0, fmt.Errorf("unterminated quoted string")
	}
	return lit, len(in) - len(left), nil
}

var casePrefix = []byte("case:")
var filePrefix = []byte("file:")

type setCase string

func isSpace(c byte) bool {
	return c == ' ' || c == '\t'
}

// Consumes KEYWORD:<arg>, where arg may be quoted.
func consumeKeyword(in []byte, kw []byte) ([]byte, int, bool, error) {
	if !bytes.HasPrefix(in, kw) {
		return nil, 0, false, nil
	}

	var arg []byte
	var err error
	left := in
	left = left[len(kw):]
	for len(left) > 0 {
		c := left[0]
		switch {
		case c == '"':
			var n int
			arg, n, err = parseStringLiteral(left)
			if err != nil {
				return nil, 0, true, err
			}

			left = left[n:]
			break
		case isSpace(c):
			break
		default:
			arg = append(arg, c)
			left = left[1:]
		}
	}

	return arg, len(in) - len(left), true, nil
}

func tryConsumeCase(in []byte) (string, int, bool, error) {
	arg, n, ok, err := consumeKeyword(in, casePrefix)
	if err != nil || !ok {
		return "", 0, ok, err
	}

	switch string(arg) {
	case "yes":
	case "no":
	case "auto":
	default:
		return "", 0, false, fmt.Errorf("unknown case argument %q, want {yes,no,auto}", arg)
	}

	return string(arg), n, true, nil
}

func tryConsumeFile(in []byte) (string, int, bool, error) {
	arg, n, ok, err := consumeKeyword(in, filePrefix)
	return string(arg), n, ok, err
}

func Parse(qStr string) (Query, error) {
	b := []byte(qStr)

	var qs []Query
	var negate bool
	var current []byte
	add := func(q Query) {
		if negate {
			q = &NotQuery{q}
		}
		qs = append(qs, q)
		negate = false
	}

	setCase := "auto"
	inWord := false
	for len(b) > 0 {
		c := b[0]

		if c == '-' && !negate {
			negate = true
			b = b[1:]
			continue
		}

		if !inWord {
			if q, n, ok, err := tryConsumeCase(b); err != nil {
				return nil, err
			} else if ok {
				setCase = q
				b = b[n:]
				continue
			}
			if fn, n, ok, err := tryConsumeFile(b); err != nil {
				return nil, err
			} else if ok {
				add(&SubstringQuery{
					Pattern:  fn,
					FileName: true,
				})
				b = b[n:]
				continue
			}

			if c == '"' {
				parse, n, err := parseStringLiteral(b)
				if err != nil {
					return nil, err
				}
				b = b[n:]

				current = append(current, parse...)
				continue
			}
		}

		if isSpace(c) {
			inWord = false
			if len(current) > 0 {
				add(&SubstringQuery{Pattern: string(current)})
				current = current[:0]
			}
			b = b[1:]
			continue
		}

		inWord = true
		current = append(current, c)
		b = b[1:]
	}

	if len(current) > 0 {
		add(&SubstringQuery{Pattern: string(current)})
	}

	qs = pushDownNegations(&AndQuery{qs}).(*AndQuery).Children

	for _, q := range qs {
		s := q.(*SubstringQuery)
		if len(s.Pattern) < 3 {
			return nil, &SuggestQueryError{
				fmt.Sprintf("pattern %q too short", s.Pattern),
				fmt.Sprintf("%q", qStr),
			}
		}
	}

	switch setCase {
	case "yes":
		for _, q := range qs {
			q.(*SubstringQuery).CaseSensitive = true
		}
	case "no":
		for _, q := range qs {
			q.(*SubstringQuery).CaseSensitive = false
		}
	case "auto":
		for _, q := range qs {
			s := q.(*SubstringQuery)
			s.CaseSensitive = (s.Pattern != string(toLower([]byte(s.Pattern))))
		}
	}

	if len(qs) == 0 {
		return nil, fmt.Errorf("empty query")
	}

	if len(qs) == 1 {
		return qs[0], nil
	}

	return &AndQuery{qs}, nil
}