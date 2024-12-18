package main

import (
	"fmt"
	"github.com/antlr4-go/antlr/v4"
	"yql-antlr-parser/parsing"
)

func main() {
	input := "SELECT user_id, name, email FROM users WHERE last_login > DATETIME('2023-12-01T00:00:00Z') ORDER BY last_login DESC LIMIT 100;"
	stream := antlr.NewInputStream(input)
	lexer := parsing.NewSQLv1Antlr4Lexer(stream)
	tokens := antlr.NewCommonTokenStream(lexer, 0)
	parser := parsing.NewSQLv1Antlr4Parser(tokens)

	tree := parser.Sql_query()
	fmt.Println(tree.ToStringTree(nil, parser))
}
