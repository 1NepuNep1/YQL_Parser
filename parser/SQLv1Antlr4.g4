grammar SQLv1Antlr4;

options {
    language = Go;
}

// Input is a list of statements.
sql_query: sql_stmt_list | PRAGMA ANSI DIGITS ansi_sql_stmt_list;
sql_stmt_list: SEMICOLON* sql_stmt (SEMICOLON+ sql_stmt)* SEMICOLON* EOF;
ansi_sql_stmt_list: SEMICOLON* EOF;

lambda_body: SEMICOLON* (lambda_stmt SEMICOLON+)* RETURN expr SEMICOLON*;
lambda_stmt:
    named_nodes_stmt
  | import_stmt
;

sql_stmt: (EXPLAIN (QUERY PLAN)?)? sql_stmt_core;

sql_stmt_core:
    pragma_stmt
  | select_stmt
  | named_nodes_stmt
  | create_table_stmt
  | drop_table_stmt
  | use_stmt
  | into_table_stmt
  | commit_stmt
  | update_stmt
  | delete_stmt
  | rollback_stmt
  | declare_stmt
  | import_stmt
  | export_stmt
  | alter_table_stmt
  | alter_external_table_stmt
  | do_stmt
  | define_action_or_subquery_stmt
  | if_stmt
  | for_stmt
  | values_stmt
  | create_user_stmt
  | alter_user_stmt
  | create_group_stmt
  | alter_group_stmt
  | drop_role_stmt
  | create_object_stmt
  | alter_object_stmt
  | drop_object_stmt
  | create_external_data_source_stmt
  | alter_external_data_source_stmt
  | drop_external_data_source_stmt
  | create_replication_stmt
  | drop_replication_stmt
  | create_topic_stmt
  | alter_topic_stmt
  | drop_topic_stmt
  | grant_permissions_stmt
  | revoke_permissions_stmt
  | alter_table_store_stmt
  | upsert_object_stmt
  | create_view_stmt
  | drop_view_stmt
  | alter_replication_stmt
  | create_resource_pool_stmt
  | alter_resource_pool_stmt
  | drop_resource_pool_stmt
  | create_backup_collection_stmt
  | alter_backup_collection_stmt
  | drop_backup_collection_stmt
  | analyze_stmt
  | create_resource_pool_classifier_stmt
  | alter_resource_pool_classifier_stmt
  | drop_resource_pool_classifier_stmt
  | backup_stmt
  | restore_stmt
  | alter_sequence_stmt
;

expr:
    or_subexpr (OR or_subexpr)*
  | type_name_composite;

or_subexpr: and_subexpr (AND and_subexpr)*;

and_subexpr: xor_subexpr (XOR xor_subexpr)*;

xor_subexpr: eq_subexpr cond_expr?;

distinct_from_op: IS NOT? DISTINCT FROM;

cond_expr:
    NOT? match_op eq_subexpr (ESCAPE eq_subexpr)?
  | NOT? IN COMPACT? in_expr
  | (ISNULL | NOTNULL | IS NULL | (IS)? NOT NULL)
  | NOT? BETWEEN (SYMMETRIC | ASYMMETRIC)? eq_subexpr AND eq_subexpr
  | ((EQUALS | EQUALS2 | NOT_EQUALS | NOT_EQUALS2 | distinct_from_op) eq_subexpr)+ /* order of the eq subexpressions is reversed! */
;

match_op: LIKE | ILIKE | GLOB | REGEXP | RLIKE | MATCH;

eq_subexpr: neq_subexpr ((LESS | LESS_OR_EQ | GREATER | GREATER_OR_EQ) neq_subexpr)*;

// workaround for recursive types, '??' and closing '>>'
shift_right: GREATER GREATER;
rot_right: GREATER GREATER PIPE;
double_question: QUESTION QUESTION;

neq_subexpr: bit_subexpr ((SHIFT_LEFT | shift_right | ROT_LEFT | rot_right | AMPERSAND | PIPE | CARET) bit_subexpr)*
  // trailing QUESTIONs are used in optional simple types (String?) and optional lambda args: ($x, $y?) -> ($x)
  (double_question neq_subexpr | QUESTION+)?;

bit_subexpr: add_subexpr ((PLUS | MINUS) add_subexpr)*;

add_subexpr: mul_subexpr ((ASTERISK | SLASH | PERCENT) mul_subexpr)*;

mul_subexpr: con_subexpr (DOUBLE_PIPE con_subexpr)*;

con_subexpr: unary_subexpr | unary_op unary_subexpr;

unary_op: PLUS | MINUS | TILDA | NOT;

unary_subexpr_suffix: ((key_expr | invoke_expr | DOT (bind_parameter | DIGITS | an_id_or_type)))* (COLLATE an_id)?;

unary_casual_subexpr: (id_expr | atom_expr) unary_subexpr_suffix;

in_unary_casual_subexpr: (id_expr_in | in_atom_expr) unary_subexpr_suffix;

unary_subexpr:    unary_casual_subexpr | json_api_expr;

in_unary_subexpr: in_unary_casual_subexpr | json_api_expr;

list_literal: LBRACE_SQUARE expr_list? COMMA? RBRACE_SQUARE;

expr_dict_list: expr (COLON expr)? (COMMA expr (COLON expr)?)*;

dict_literal: LBRACE_CURLY expr_dict_list? COMMA? RBRACE_CURLY;

expr_struct_list: expr COLON expr (COMMA expr COLON expr)*;

struct_literal: STRUCT_OPEN expr_struct_list? COMMA? STRUCT_CLOSE;

atom_expr:
    literal_value
  | bind_parameter
  | lambda
  | cast_expr
  | exists_expr
  | case_expr
  | an_id_or_type NAMESPACE (id_or_type | STRING_VALUE)
  | value_constructor
  | bitcast_expr
  | list_literal
  | dict_literal
  | struct_literal
;

in_atom_expr:
    literal_value
  | bind_parameter
  | lambda
  | cast_expr
  | case_expr
  | an_id_or_type NAMESPACE (id_or_type | STRING_VALUE)
  | LPAREN select_stmt RPAREN
// TODO: resolve ANTLR error: rule in_atom_expr has non-LL(*) decision due to recursive rule invocations reachable from alts 3,8
//  | LPAREN values_stmt RPAREN
  | value_constructor
  | bitcast_expr
  | list_literal
  | dict_literal
  | struct_literal
;

cast_expr: CAST LPAREN expr AS type_name_or_bind RPAREN;

bitcast_expr: BITCAST LPAREN expr AS type_name_simple RPAREN;

exists_expr: EXISTS LPAREN (select_stmt | values_stmt) RPAREN;

case_expr: CASE expr? when_expr+ (ELSE expr)? END;

lambda: smart_parenthesis (ARROW (LPAREN expr RPAREN | LBRACE_CURLY lambda_body RBRACE_CURLY) )?;

in_expr: in_unary_subexpr;

// ANSI SQL JSON support
json_api_expr: json_value | json_exists | json_query;

jsonpath_spec: STRING_VALUE;

json_variable_name: id_expr | STRING_VALUE;

json_variable: expr AS json_variable_name;

json_variables: json_variable (COMMA json_variable)*;

json_common_args: expr COMMA jsonpath_spec (PASSING json_variables)?;

json_case_handler: ERROR | NULL | DEFAULT expr;

json_value: JSON_VALUE LPAREN
  json_common_args
  (RETURNING type_name_simple)?
  (json_case_handler ON (EMPTY | ERROR))*
RPAREN;

json_exists_handler: (TRUE | FALSE | UNKNOWN | ERROR) ON ERROR;

json_exists: JSON_EXISTS LPAREN
  json_common_args
  json_exists_handler?
RPAREN;

json_query_wrapper: WITHOUT ARRAY? | WITH (CONDITIONAL | UNCONDITIONAL)? ARRAY?;
json_query_handler: ERROR | NULL | EMPTY ARRAY | EMPTY OBJECT;

json_query: JSON_QUERY LPAREN
  json_common_args
  (json_query_wrapper WRAPPER)?
  (json_query_handler ON EMPTY)?
  (json_query_handler ON ERROR)?
RPAREN;

// struct, tuple or named list
smart_parenthesis: LPAREN named_expr_list? COMMA? RPAREN;

expr_list: expr (COMMA expr)*;

pure_column_list: LPAREN an_id (COMMA an_id)* RPAREN;

pure_column_or_named: bind_parameter | an_id;
pure_column_or_named_list: LPAREN pure_column_or_named (COMMA pure_column_or_named)* RPAREN;

column_name: opt_id_prefix an_id;
without_column_name: an_id DOT an_id | an_id_without;

column_list: column_name (COMMA column_name)* COMMA?;
without_column_list: without_column_name (COMMA without_column_name)* COMMA?;

named_expr: expr (AS an_id_or_type)?;

named_expr_list: named_expr (COMMA named_expr)*;

invoke_expr: LPAREN (opt_set_quantifier named_expr_list COMMA? | ASTERISK)? RPAREN invoke_expr_tail;

// null_treatment can only happen after window functions LAG/LEAD/NTH/FIRST_VALUE/LAST_VALUE
// filter_clause can only happen after aggregation functions
invoke_expr_tail:
    (null_treatment | filter_clause)? (OVER window_name_or_specification)?
;

using_call_expr: (an_id_or_type NAMESPACE an_id_or_type | an_id_expr | bind_parameter | EXTERNAL FUNCTION) invoke_expr;

key_expr: LBRACE_SQUARE expr RBRACE_SQUARE;

when_expr: WHEN expr THEN expr;

literal_value:
    integer
  | real
  | STRING_VALUE
  | BLOB // it's unused right now
  | NULL
  | CURRENT_TIME // it's unused right now
  | CURRENT_DATE // it's unused right now
  | CURRENT_TIMESTAMP // it's unused right now
  | bool_value
  | EMPTY_ACTION
;

bind_parameter: DOLLAR (an_id_or_type | TRUE | FALSE);
opt_bind_parameter: bind_parameter QUESTION?;

bind_parameter_list: bind_parameter (COMMA bind_parameter)*;
named_bind_parameter: bind_parameter (AS bind_parameter)?;
named_bind_parameter_list: named_bind_parameter (COMMA named_bind_parameter)*;

signed_number: (PLUS | MINUS)? (integer | real);

type_name_simple: an_id_pure;

integer_or_bind: integer | bind_parameter;
type_name_tag: id | STRING_VALUE | bind_parameter;

struct_arg: type_name_tag COLON type_name_or_bind;
struct_arg_positional:
    type_name_tag type_name_or_bind (NOT? NULL)?
  | type_name_or_bind AS type_name_tag; //deprecated
variant_arg: (type_name_tag COLON)? type_name_or_bind;
callable_arg: variant_arg (LBRACE_CURLY AUTOMAP RBRACE_CURLY)?;
callable_arg_list: callable_arg (COMMA callable_arg)*;

type_name_decimal: DECIMAL LPAREN integer_or_bind COMMA integer_or_bind RPAREN;
type_name_optional: OPTIONAL LESS type_name_or_bind GREATER;
type_name_tuple: TUPLE (LESS (type_name_or_bind (COMMA type_name_or_bind)* COMMA?)? GREATER | NOT_EQUALS2);
type_name_struct: STRUCT (LESS (struct_arg (COMMA struct_arg)* COMMA?)? GREATER | NOT_EQUALS2);
type_name_variant: VARIANT LESS variant_arg (COMMA variant_arg)* COMMA? GREATER;
type_name_list: LIST LESS type_name_or_bind GREATER;
type_name_stream: STREAM LESS type_name_or_bind GREATER;
type_name_flow: FLOW LESS type_name_or_bind GREATER;
type_name_dict: DICT LESS type_name_or_bind COMMA type_name_or_bind GREATER;
type_name_set: SET LESS type_name_or_bind GREATER;
type_name_enum: ENUM LESS type_name_tag (COMMA type_name_tag)* COMMA? GREATER;
type_name_resource: RESOURCE LESS type_name_tag GREATER;
type_name_tagged: TAGGED LESS type_name_or_bind COMMA type_name_tag GREATER;
type_name_callable: CALLABLE LESS LPAREN callable_arg_list? COMMA? (LBRACE_SQUARE callable_arg_list RBRACE_SQUARE)? RPAREN ARROW type_name_or_bind GREATER;

type_name_composite:
  ( type_name_optional
  | type_name_tuple
  | type_name_struct
  | type_name_variant
  | type_name_list
  | type_name_stream
  | type_name_flow
  | type_name_dict
  | type_name_set
  | type_name_enum
  | type_name_resource
  | type_name_tagged
  | type_name_callable
  ) QUESTION*;

type_name:
    type_name_composite
  | (type_name_decimal | type_name_simple) QUESTION*;

type_name_or_bind: type_name | bind_parameter;

value_constructor_literal: STRING_VALUE;
value_constructor:
    VARIANT LPAREN expr COMMA expr COMMA expr RPAREN
  | ENUM LPAREN expr COMMA expr RPAREN
  | CALLABLE LPAREN expr COMMA expr RPAREN
;

declare_stmt: DECLARE bind_parameter AS type_name (EQUALS literal_value)?;

module_path: DOT? an_id (DOT an_id)*;
import_stmt: IMPORT module_path SYMBOLS named_bind_parameter_list;
export_stmt: EXPORT bind_parameter_list;

call_action: (bind_parameter | EMPTY_ACTION) LPAREN expr_list? RPAREN;
inline_action: BEGIN define_action_or_subquery_body END DO;
do_stmt: DO (call_action | inline_action);
pragma_stmt: PRAGMA opt_id_prefix_or_type an_id (EQUALS pragma_value | LPAREN pragma_value (COMMA pragma_value)* RPAREN)?;

pragma_value:
    signed_number
  | id
  | STRING_VALUE
  | bool_value
  | bind_parameter
;

/// TODO: NULLS FIRST\LAST?
sort_specification: expr (ASC | DESC)?;

sort_specification_list: sort_specification (COMMA sort_specification)*;

select_stmt: select_kind_parenthesis (select_op select_kind_parenthesis)*;

select_unparenthesized_stmt: select_kind_partial (select_op select_kind_parenthesis)*;

select_kind_parenthesis: select_kind_partial | LPAREN select_kind_partial RPAREN;

select_op: UNION (ALL)? | INTERSECT | EXCEPT;

select_kind_partial: select_kind
  (LIMIT expr ((OFFSET | COMMA) expr)?)?
  ;

select_kind: (DISCARD)? (process_core | reduce_core | select_core) (INTO RESULT pure_column_or_named)?;

process_core:
  PROCESS STREAM? named_single_source (COMMA named_single_source)* (USING using_call_expr (AS an_id)?
  (WITH external_call_settings)?
  (WHERE expr)? (HAVING expr)? (ASSUME order_by_clause)?)?
;

external_call_param: an_id EQUALS expr;
external_call_settings: external_call_param (COMMA external_call_param)*;

reduce_core:
  REDUCE named_single_source (COMMA named_single_source)* (PRESORT sort_specification_list)?
  ON column_list USING ALL? using_call_expr (AS an_id)?
  (WHERE expr)? (HAVING expr)? (ASSUME order_by_clause)?
;

opt_set_quantifier: (ALL | DISTINCT)?;

select_core:
  (FROM join_source)? SELECT STREAM? opt_set_quantifier result_column (COMMA result_column)* COMMA? (WITHOUT without_column_list)? (FROM join_source)? (WHERE expr)?
  group_by_clause? (HAVING expr)? window_clause? ext_order_by_clause?
;

// ISO/IEC 9075-2:2016(E) 7.7 <row pattern recognition clause>
row_pattern_recognition_clause: MATCH_RECOGNIZE LPAREN
    window_partition_clause?
    order_by_clause?
    row_pattern_measures?
    row_pattern_rows_per_match?
    row_pattern_common_syntax
  RPAREN
;

row_pattern_rows_per_match:
      ONE ROW PER MATCH
    | ALL ROWS PER MATCH row_pattern_empty_match_handling?
;

row_pattern_empty_match_handling: SHOW EMPTY MATCHES | OMIT EMPTY MATCHES | WITH UNMATCHED ROWS;

// ISO/IEC 9075-2:2016(E) 7.8 <row pattern measures>
row_pattern_measures: MEASURES row_pattern_measure_list;

row_pattern_measure_list: row_pattern_measure_definition (COMMA row_pattern_measure_definition)*;

row_pattern_measure_definition: expr AS an_id;

// ISO/IEC 9075-2:2016(E) 7.9 <row pattern common syntax>
row_pattern_common_syntax:
    (AFTER MATCH row_pattern_skip_to)?
    row_pattern_initial_or_seek?
    PATTERN LPAREN row_pattern RPAREN
    row_pattern_subset_clause?
    DEFINE row_pattern_definition_list
;

row_pattern_skip_to:
      TSKIP TO NEXT ROW
    | TSKIP PAST LAST ROW
    | TSKIP TO FIRST row_pattern_skip_to_variable_name
    | TSKIP TO LAST row_pattern_skip_to_variable_name
    | TSKIP TO row_pattern_skip_to_variable_name
;

row_pattern_skip_to_variable_name: row_pattern_variable_name;

row_pattern_initial_or_seek: INITIAL | SEEK;

row_pattern: row_pattern_term (PIPE row_pattern_term)*;

row_pattern_term: row_pattern_factor+;

row_pattern_factor: row_pattern_primary row_pattern_quantifier?;

row_pattern_quantifier:
      ASTERISK QUESTION?
    | PLUS QUESTION?
    | QUESTION QUESTION?
    | LBRACE_CURLY integer? COMMA integer? RBRACE_CURLY QUESTION?
    | LBRACE_CURLY integer RBRACE_CURLY
;

row_pattern_primary:
      row_pattern_primary_variable_name
    | DOLLAR
    | CARET
    | LPAREN row_pattern? RPAREN
    | LBRACE_CURLY MINUS row_pattern MINUS RBRACE_CURLY
    | row_pattern_permute
;

row_pattern_primary_variable_name: row_pattern_variable_name;

row_pattern_permute: PERMUTE LPAREN
    row_pattern (COMMA row_pattern)*
    RPAREN
;

row_pattern_subset_clause: SUBSET row_pattern_subset_list;

row_pattern_subset_list: row_pattern_subset_item (COMMA row_pattern_subset_item)*;

row_pattern_subset_item: row_pattern_subset_item_variable_name EQUALS LPAREN
    row_pattern_subset_rhs RPAREN
;

row_pattern_subset_item_variable_name: row_pattern_variable_name;

row_pattern_subset_rhs: row_pattern_subset_rhs_variable_name (COMMA row_pattern_subset_rhs_variable_name)*;

row_pattern_subset_rhs_variable_name: row_pattern_variable_name;

row_pattern_definition_list: row_pattern_definition (COMMA row_pattern_definition)*;

row_pattern_definition: row_pattern_definition_variable_name AS row_pattern_definition_search_condition;

row_pattern_definition_variable_name: row_pattern_variable_name;

row_pattern_definition_search_condition: search_condition;

search_condition: expr;

//TODO allow use tokens as vars https://st.yandex-team.ru/YQL-16223
row_pattern_variable_name: identifier;

order_by_clause: ORDER BY sort_specification_list;

ext_order_by_clause: ASSUME? order_by_clause;

group_by_clause: GROUP COMPACT? BY opt_set_quantifier grouping_element_list (WITH an_id)?;

grouping_element_list: grouping_element (COMMA grouping_element)*;

grouping_element:
    ordinary_grouping_set
  | rollup_list
  | cube_list
  | grouping_sets_specification
//empty_grouping_set inside smart_parenthesis
  | hopping_window_specification
;

/// expect column (named column), or parenthesis list columns, or expression (named expression), or list expression
ordinary_grouping_set: named_expr;
ordinary_grouping_set_list: ordinary_grouping_set (COMMA ordinary_grouping_set)*;

rollup_list: ROLLUP LPAREN ordinary_grouping_set_list RPAREN;
cube_list: CUBE LPAREN ordinary_grouping_set_list RPAREN;

/// SQL2003 grouping_set_list == grouping_element_list
grouping_sets_specification: GROUPING SETS LPAREN grouping_element_list RPAREN;

hopping_window_specification: HOP LPAREN expr COMMA expr COMMA expr COMMA expr RPAREN;

result_column:
    opt_id_prefix ASTERISK
  | expr (AS an_id_or_type | an_id_as_compat)?
;

join_source: ANY? flatten_source (join_op ANY? flatten_source join_constraint?)*;

named_column: column_name (AS an_id)?;

flatten_by_arg:
    named_column
  | LPAREN named_expr_list COMMA? RPAREN
;

flatten_source: named_single_source (FLATTEN ((OPTIONAL|LIST|DICT)? BY flatten_by_arg | COLUMNS))?;

named_single_source: single_source row_pattern_recognition_clause? ((AS an_id | an_id_as_compat) pure_column_list?)? (sample_clause | tablesample_clause)?;

single_source:
    table_ref
  | LPAREN select_stmt RPAREN
  | LPAREN values_stmt RPAREN
;

sample_clause: SAMPLE expr;

tablesample_clause: TABLESAMPLE sampling_mode LPAREN expr RPAREN repeatable_clause?;

sampling_mode: (BERNOULLI | SYSTEM);

repeatable_clause: REPEATABLE LPAREN expr RPAREN;

join_op:
    COMMA
  | (NATURAL)? ((LEFT (ONLY | SEMI)? | RIGHT (ONLY | SEMI)? | EXCLUSION | FULL)? (OUTER)? | INNER | CROSS) JOIN
;

join_constraint:
    ON expr
  | USING pure_column_or_named_list
;

returning_columns_list: RETURNING (ASTERISK | an_id (COMMA an_id)*);

into_table_stmt: (INSERT | INSERT OR ABORT | INSERT OR REVERT | INSERT OR IGNORE | UPSERT | REPLACE) INTO into_simple_table_ref into_values_source returning_columns_list?;

into_values_source:
    pure_column_list? values_source
  | DEFAULT VALUES
;

values_stmt: VALUES values_source_row_list;

values_source: values_stmt | select_stmt;
values_source_row_list: values_source_row (COMMA values_source_row)*;
values_source_row: LPAREN expr_list RPAREN;

simple_values_source: expr_list | select_stmt;

create_external_data_source_stmt: CREATE (OR REPLACE)? EXTERNAL DATA SOURCE (IF NOT EXISTS)? object_ref
    with_table_settings
;

alter_external_data_source_stmt: ALTER EXTERNAL DATA SOURCE object_ref
    alter_external_data_source_action (COMMA alter_external_data_source_action)*
;
alter_external_data_source_action:
    alter_table_set_table_setting_uncompat
  | alter_table_set_table_setting_compat
  | alter_table_reset_table_setting
//| alter_table_rename_to // TODO
;

drop_external_data_source_stmt: DROP EXTERNAL DATA SOURCE (IF EXISTS)? object_ref;

create_view_stmt: CREATE VIEW (IF NOT EXISTS)? object_ref
    create_object_features?
    AS select_stmt
;

drop_view_stmt: DROP VIEW (IF EXISTS)? object_ref;

upsert_object_stmt: UPSERT OBJECT object_ref
    LPAREN TYPE object_type_ref RPAREN
    create_object_features?
;
create_object_stmt: CREATE OBJECT (IF NOT EXISTS)? object_ref
    LPAREN TYPE object_type_ref RPAREN
    create_object_features?
;
create_object_features: WITH object_features;

alter_object_stmt: ALTER OBJECT object_ref
    LPAREN TYPE object_type_ref RPAREN
    alter_object_features
;
alter_object_features: SET object_features;

drop_object_stmt: DROP OBJECT (IF EXISTS)? object_ref
    LPAREN TYPE object_type_ref RPAREN
    drop_object_features?
;
drop_object_features: WITH object_features;

object_feature_value: id_or_type | bind_parameter | STRING_VALUE | bool_value;
object_feature_kv: an_id_or_type EQUALS object_feature_value;
object_feature_flag: an_id_or_type;
object_feature: object_feature_kv | object_feature_flag;
object_features: object_feature | LPAREN object_feature (COMMA object_feature)* RPAREN;

object_type_ref: an_id_or_type;

create_table_stmt: CREATE (OR REPLACE)? (TABLE | TABLESTORE | EXTERNAL TABLE | TEMP TABLE | TEMPORARY TABLE) (IF NOT EXISTS)? simple_table_ref LPAREN create_table_entry (COMMA create_table_entry)* COMMA? RPAREN
    table_inherits?
    table_partition_by?
    with_table_settings?
    table_tablestore?
    table_as_source?;
create_table_entry:
    column_schema
  | table_constraint
  | table_index
  | family_entry
  | changefeed
  | an_id_schema
;

create_backup_collection_stmt: CREATE backup_collection create_backup_collection_entries? WITH LPAREN backup_collection_settings RPAREN;
alter_backup_collection_stmt: ALTER backup_collection (alter_backup_collection_actions | alter_backup_collection_entries);
drop_backup_collection_stmt: DROP backup_collection;

create_backup_collection_entries: DATABASE | create_backup_collection_entries_many;
create_backup_collection_entries_many: LPAREN table_list RPAREN;
table_list: TABLE an_id_table (COMMA TABLE an_id_table)*;

alter_backup_collection_actions: alter_backup_collection_action (COMMA alter_backup_collection_action)*;
alter_backup_collection_action:
    alter_table_set_table_setting_compat
  | alter_table_reset_table_setting
;
alter_backup_collection_entries: alter_backup_collection_entry (COMMA alter_backup_collection_entry)*;
alter_backup_collection_entry:
    ADD DATABASE
  | DROP DATABASE
  | ADD TABLE an_id_table
  | DROP TABLE an_id_table
;
backup_collection: BACKUP COLLECTION object_ref;
backup_collection_settings: backup_collection_settings_entry (COMMA backup_collection_settings_entry)*;
backup_collection_settings_entry: an_id EQUALS table_setting_value;

backup_stmt: BACKUP object_ref (INCREMENTAL)?;
restore_stmt: RESTORE object_ref (AT STRING_VALUE)?;

table_inherits: INHERITS LPAREN simple_table_ref_core (COMMA simple_table_ref_core)* RPAREN;
table_partition_by: PARTITION BY HASH pure_column_list;
with_table_settings: WITH LPAREN table_settings_entry (COMMA table_settings_entry)* RPAREN;
table_tablestore: TABLESTORE simple_table_ref_core;
table_settings_entry: an_id EQUALS table_setting_value;
table_as_source: AS values_source;

alter_table_stmt: ALTER TABLE simple_table_ref alter_table_action (COMMA alter_table_action)*;
alter_table_action:
    alter_table_add_column
  | alter_table_drop_column
  | alter_table_alter_column
  | alter_table_add_column_family
  | alter_table_alter_column_family
  | alter_table_set_table_setting_uncompat
  | alter_table_set_table_setting_compat
  | alter_table_reset_table_setting
  | alter_table_add_index
  | alter_table_drop_index
  | alter_table_rename_to
  | alter_table_add_changefeed
  | alter_table_alter_changefeed
  | alter_table_drop_changefeed
  | alter_table_rename_index_to
  | alter_table_alter_index
  | alter_table_alter_column_drop_not_null
;

alter_external_table_stmt: ALTER EXTERNAL TABLE simple_table_ref alter_external_table_action (COMMA alter_external_table_action)*;
alter_external_table_action:
    alter_table_add_column
  | alter_table_drop_column
  | alter_table_set_table_setting_uncompat
  | alter_table_set_table_setting_compat
  | alter_table_reset_table_setting
//| alter_table_rename_to // TODO
;

alter_table_store_stmt: ALTER TABLESTORE object_ref alter_table_store_action (COMMA alter_table_store_action)*;
alter_table_store_action:
    alter_table_add_column
  | alter_table_drop_column
;

alter_table_add_column: ADD COLUMN? column_schema;
alter_table_drop_column: DROP COLUMN? an_id;
alter_table_alter_column: ALTER COLUMN an_id SET family_relation;
alter_table_alter_column_drop_not_null: ALTER COLUMN an_id DROP NOT NULL;
alter_table_add_column_family: ADD family_entry;
alter_table_alter_column_family: ALTER FAMILY an_id SET an_id family_setting_value;
alter_table_set_table_setting_uncompat: SET an_id table_setting_value;
alter_table_set_table_setting_compat: SET LPAREN alter_table_setting_entry (COMMA alter_table_setting_entry)* RPAREN;
alter_table_reset_table_setting: RESET LPAREN an_id (COMMA an_id)* RPAREN;
alter_table_add_index: ADD table_index;
alter_table_drop_index: DROP INDEX an_id;
alter_table_rename_to: RENAME TO an_id_table;
alter_table_rename_index_to: RENAME INDEX an_id TO an_id;
alter_table_add_changefeed: ADD changefeed;
alter_table_alter_changefeed: ALTER CHANGEFEED an_id changefeed_alter_settings;
alter_table_drop_changefeed: DROP CHANGEFEED an_id;
alter_table_alter_index: ALTER INDEX an_id alter_table_alter_index_action;

column_schema: an_id_schema type_name_or_bind family_relation? opt_column_constraints;
family_relation: FAMILY an_id;
opt_column_constraints: (NOT? NULL)? (DEFAULT expr)?;
column_order_by_specification: an_id (ASC | DESC)?;

table_constraint:
    PRIMARY KEY LPAREN an_id (COMMA an_id)* RPAREN
  | PARTITION BY LPAREN an_id (COMMA an_id)* RPAREN
  | ORDER BY LPAREN column_order_by_specification (COMMA column_order_by_specification)* RPAREN
;

table_index: INDEX an_id table_index_type
    ON LPAREN an_id_schema (COMMA an_id_schema)* RPAREN
    (COVER LPAREN an_id_schema (COMMA an_id_schema)* RPAREN)?
    with_index_settings?
;

table_index_type: (global_index | local_index) (USING index_subtype)?;

global_index: GLOBAL UNIQUE? (SYNC | ASYNC)?;
local_index: LOCAL;

index_subtype: an_id;

with_index_settings: WITH LPAREN index_setting_entry (COMMA index_setting_entry)* COMMA? RPAREN;
index_setting_entry: an_id EQUALS index_setting_value;
index_setting_value:
      id_or_type
    | STRING_VALUE
    | integer
    | bool_value
;

changefeed: CHANGEFEED an_id WITH LPAREN changefeed_settings RPAREN;
changefeed_settings: changefeed_settings_entry (COMMA changefeed_settings_entry)*;
changefeed_settings_entry: an_id EQUALS changefeed_setting_value;
changefeed_setting_value: expr;
changefeed_alter_settings:
    DISABLE
  | SET LPAREN changefeed_settings RPAREN
;

alter_table_setting_entry: an_id EQUALS table_setting_value;

table_setting_value:
      id
    | STRING_VALUE
    | integer
    | split_boundaries
    | ttl_tier_list ON an_id (AS (SECONDS | MILLISECONDS | MICROSECONDS | NANOSECONDS))?
    | bool_value
;

ttl_tier_list: expr (ttl_tier_action (COMMA expr ttl_tier_action)*)?;
ttl_tier_action:
      TO EXTERNAL DATA SOURCE an_id
    | DELETE
;

family_entry: FAMILY an_id family_settings;
family_settings: LPAREN (family_settings_entry (COMMA family_settings_entry)*)? RPAREN;
family_settings_entry: an_id EQUALS family_setting_value;
family_setting_value:
        STRING_VALUE
      | integer
;

split_boundaries:
      LPAREN literal_value_list (COMMA literal_value_list)* RPAREN
    | literal_value_list
;

literal_value_list: LPAREN literal_value (COMMA literal_value)* RPAREN;

alter_table_alter_index_action:
    alter_table_set_table_setting_uncompat
  | alter_table_set_table_setting_compat
  | alter_table_reset_table_setting
;

drop_table_stmt: DROP (TABLE | TABLESTORE | EXTERNAL TABLE) (IF EXISTS)? simple_table_ref;

create_user_stmt: CREATE USER role_name create_user_option?;
alter_user_stmt: ALTER USER role_name (WITH? create_user_option | RENAME TO role_name);

create_group_stmt: CREATE GROUP role_name (WITH USER role_name (COMMA role_name)* COMMA?)?;
alter_group_stmt: ALTER GROUP role_name ((ADD|DROP) USER role_name (COMMA role_name)* COMMA? | RENAME TO role_name);

drop_role_stmt: DROP (USER|GROUP) (IF EXISTS)? role_name (COMMA role_name)* COMMA?;

role_name: an_id_or_type | bind_parameter;
create_user_option: ENCRYPTED? PASSWORD expr;

grant_permissions_stmt: GRANT permission_name_target ON an_id_schema (COMMA an_id_schema)* TO role_name (COMMA role_name)* COMMA? (WITH GRANT OPTION)?;
revoke_permissions_stmt: REVOKE (GRANT OPTION FOR)? permission_name_target ON an_id_schema (COMMA an_id_schema)* FROM role_name (COMMA role_name)*;

permission_id:
      CONNECT
    | LIST
    | INSERT
    | MANAGE
    | DROP
    | GRANT
    | MODIFY (TABLES | ATTRIBUTES)
    | (UPDATE | ERASE) ROW
    | (REMOVE | DESCRIBE | ALTER) SCHEMA
    | SELECT (TABLES | ATTRIBUTES | ROW)?
    | (USE | FULL) LEGACY?
    | CREATE (DIRECTORY | TABLE | QUEUE)?
;

permission_name: permission_id | STRING_VALUE;

permission_name_target: permission_name (COMMA permission_name)* COMMA? | ALL PRIVILEGES?;

create_resource_pool_stmt: CREATE RESOURCE POOL object_ref
  with_table_settings
;

alter_resource_pool_stmt: ALTER RESOURCE POOL object_ref
  alter_resource_pool_action (COMMA alter_resource_pool_action)*
;
alter_resource_pool_action:
    alter_table_set_table_setting_compat
  | alter_table_reset_table_setting
;

drop_resource_pool_stmt: DROP RESOURCE POOL object_ref;

create_resource_pool_classifier_stmt: CREATE RESOURCE POOL CLASSIFIER object_ref
  with_table_settings
;

alter_resource_pool_classifier_stmt: ALTER RESOURCE POOL CLASSIFIER object_ref
  alter_resource_pool_classifier_action (COMMA alter_resource_pool_classifier_action)*
;
alter_resource_pool_classifier_action:
    alter_table_set_table_setting_compat
  | alter_table_reset_table_setting
;

drop_resource_pool_classifier_stmt: DROP RESOURCE POOL CLASSIFIER object_ref;

create_replication_stmt: CREATE ASYNC REPLICATION object_ref
    FOR replication_target (COMMA replication_target)*
    WITH LPAREN replication_settings RPAREN
;

replication_target: object_ref AS object_ref;
replication_settings: replication_settings_entry (COMMA replication_settings_entry)*;
replication_settings_entry: an_id EQUALS expr;

alter_replication_stmt: ALTER ASYNC REPLICATION object_ref alter_replication_action (COMMA alter_replication_action)*;
alter_replication_action:
    alter_replication_set_setting
;

alter_replication_set_setting: SET LPAREN replication_settings RPAREN;

drop_replication_stmt: DROP ASYNC REPLICATION object_ref CASCADE?;

action_or_subquery_args: opt_bind_parameter (COMMA opt_bind_parameter)*;

define_action_or_subquery_stmt: DEFINE (ACTION|SUBQUERY) bind_parameter LPAREN action_or_subquery_args? RPAREN AS define_action_or_subquery_body END DEFINE;
define_action_or_subquery_body: SEMICOLON* (sql_stmt_core (SEMICOLON+ sql_stmt_core)* SEMICOLON*)?;

if_stmt: EVALUATE? IF expr do_stmt (ELSE do_stmt)?;
for_stmt: EVALUATE? PARALLEL? FOR bind_parameter IN expr do_stmt (ELSE do_stmt)?;

table_ref: (cluster_expr DOT)? COMMAT? (table_key | an_id_expr LPAREN (table_arg (COMMA table_arg)* COMMA?)? RPAREN | bind_parameter (LPAREN expr_list? RPAREN)? (VIEW view_name)?) table_hints?;

table_key: id_table_or_type (VIEW view_name)?;
table_arg: COMMAT? named_expr (VIEW view_name)?;
table_hints: WITH (table_hint | LPAREN table_hint (COMMA table_hint)* RPAREN);
table_hint:
      an_id_hint (EQUALS (type_name_tag | LPAREN type_name_tag (COMMA type_name_tag)* COMMA? RPAREN))?
    | (SCHEMA | COLUMNS) EQUALS? type_name_or_bind
    | SCHEMA EQUALS? LPAREN (struct_arg_positional (COMMA struct_arg_positional)*)? COMMA? RPAREN
;

object_ref: (cluster_expr DOT)? id_or_at;
simple_table_ref_core: object_ref | COMMAT? bind_parameter;
simple_table_ref: simple_table_ref_core table_hints?;
into_simple_table_ref: simple_table_ref (ERASE BY pure_column_list)?;

delete_stmt: DELETE FROM simple_table_ref (WHERE expr | ON into_values_source)? returning_columns_list?;
update_stmt: UPDATE simple_table_ref (SET set_clause_choice (WHERE expr)? | ON into_values_source)  returning_columns_list?;

/// out of 2003 standart
set_clause_choice: set_clause_list | multiple_column_assignment;

set_clause_list: set_clause (COMMA set_clause)*;
set_clause: set_target EQUALS expr;
set_target: column_name;
multiple_column_assignment: set_target_list EQUALS LPAREN simple_values_source RPAREN;
set_target_list: LPAREN set_target (COMMA set_target)* RPAREN;

// topics
create_topic_stmt: CREATE TOPIC (IF NOT EXISTS)? topic_ref create_topic_entries? with_topic_settings?;

create_topic_entries: LPAREN create_topic_entry (COMMA create_topic_entry)* RPAREN;
create_topic_entry:
    topic_create_consumer_entry
;
with_topic_settings: WITH LPAREN topic_settings RPAREN;

alter_topic_stmt: ALTER TOPIC (IF EXISTS)? topic_ref alter_topic_action (COMMA alter_topic_action)*;
alter_topic_action:
    alter_topic_add_consumer
  | alter_topic_alter_consumer
  | alter_topic_drop_consumer
  | alter_topic_set_settings
  | alter_topic_reset_settings
;

alter_topic_add_consumer: ADD topic_create_consumer_entry;
topic_create_consumer_entry: CONSUMER an_id topic_consumer_with_settings?;

alter_topic_alter_consumer: ALTER CONSUMER topic_consumer_ref alter_topic_alter_consumer_entry;
alter_topic_alter_consumer_entry:
    topic_alter_consumer_set
  | topic_alter_consumer_reset
;

alter_topic_drop_consumer: DROP CONSUMER topic_consumer_ref;

topic_alter_consumer_set: SET LPAREN topic_consumer_settings RPAREN;
topic_alter_consumer_reset: RESET LPAREN an_id (COMMA an_id)* RPAREN;

alter_topic_set_settings: SET LPAREN topic_settings RPAREN;
alter_topic_reset_settings: RESET LPAREN an_id (COMMA an_id_pure)* RPAREN;

drop_topic_stmt: DROP TOPIC (IF EXISTS)? topic_ref;

topic_settings: topic_settings_entry (COMMA topic_settings_entry)*;
topic_settings_entry: an_id EQUALS topic_setting_value;
topic_setting_value:
    expr
;

topic_consumer_with_settings: WITH LPAREN topic_consumer_settings RPAREN;
topic_consumer_settings: topic_consumer_settings_entry (COMMA topic_consumer_settings_entry)*;
topic_consumer_settings_entry: an_id EQUALS topic_consumer_setting_value;
topic_consumer_setting_value:
    expr
;

topic_ref: (cluster_expr DOT)? an_id;
topic_consumer_ref: an_id_pure;

/// window function supp
// differ from 2003 for resolve conflict
null_treatment: RESPECT NULLS | IGNORE NULLS;

filter_clause: FILTER LPAREN WHERE expr RPAREN;

window_name_or_specification: window_name | window_specification;

window_name: an_id_window;

window_clause: WINDOW window_definition_list;

window_definition_list: window_definition (COMMA window_definition)*;

window_definition: new_window_name AS window_specification;

new_window_name: window_name;

window_specification: LPAREN window_specification_details RPAREN;

window_specification_details:
    existing_window_name?
    window_partition_clause?
    window_order_clause?
    window_frame_clause?
;

existing_window_name: window_name;
window_partition_clause: PARTITION COMPACT? BY named_expr_list;
window_order_clause: order_by_clause;

window_frame_clause: window_frame_units window_frame_extent window_frame_exclusion?;
window_frame_units: ROWS | RANGE | GROUPS;

window_frame_extent: window_frame_bound | window_frame_between;

window_frame_between: BETWEEN window_frame_bound AND window_frame_bound;

window_frame_bound:
    CURRENT ROW
  | (expr | UNBOUNDED) (PRECEDING | FOLLOWING)
;

window_frame_exclusion: EXCLUDE CURRENT ROW | EXCLUDE GROUP | EXCLUDE TIES | EXCLUDE NO OTHERS;

// EXTRAS
use_stmt: USE cluster_expr;

subselect_stmt: (LPAREN select_stmt RPAREN | select_unparenthesized_stmt);

// TODO: [fatal] rule named_nodes_stmt has non-LL(*) decision due to recursive rule invocations reachable from alts 1,3
// named_nodes_stmt: bind_parameter_list EQUALS (expr | subselect_stmt | values_stmt | LPAREN values_stmt RPAREN);
named_nodes_stmt: bind_parameter_list EQUALS (expr | subselect_stmt);

commit_stmt: COMMIT;

rollback_stmt: ROLLBACK;

analyze_table: simple_table_ref (LPAREN column_list RPAREN)?;
analyze_table_list: analyze_table (COMMA analyze_table)* COMMA?;
analyze_stmt: ANALYZE analyze_table_list;

alter_sequence_stmt: ALTER SEQUENCE (IF EXISTS)? object_ref alter_sequence_action+;
alter_sequence_action:
  START WITH? integer
  | RESTART WITH? integer
  | RESTART
  | INCREMENT BY? integer
;

// Special rules that allow to use certain keywords as identifiers.
identifier: ID_PLAIN | ID_QUOTED;
id: identifier | keyword;

id_schema:
    identifier
  | keyword_compat
  | keyword_expr_uncompat
//  | keyword_table_uncompat
  | keyword_select_uncompat
//  | keyword_alter_uncompat
  | keyword_in_uncompat
  | keyword_window_uncompat
  | keyword_hint_uncompat
;

id_expr:
    identifier
  | keyword_compat
//  | keyword_expr_uncompat
//  | keyword_table_uncompat
//  | keyword_select_uncompat
  | keyword_alter_uncompat
  | keyword_in_uncompat
  | keyword_window_uncompat
  | keyword_hint_uncompat
;

id_expr_in:
    identifier
  | keyword_compat
//  | keyword_expr_uncompat
//  | keyword_table_uncompat
//  | keyword_select_uncompat
  | keyword_alter_uncompat
//  | keyword_in_uncompat
  | keyword_window_uncompat
  | keyword_hint_uncompat
;

id_window:
    identifier
  | keyword_compat
  | keyword_expr_uncompat
  | keyword_table_uncompat
  | keyword_select_uncompat
  | keyword_alter_uncompat
  | keyword_in_uncompat
//  | keyword_window_uncompat
  | keyword_hint_uncompat
;

id_table:
    identifier
  | keyword_compat
  | keyword_expr_uncompat
//  | keyword_table_uncompat
  | keyword_select_uncompat
//  | keyword_alter_uncompat
  | keyword_in_uncompat
  | keyword_window_uncompat
  | keyword_hint_uncompat
;

id_without:
    identifier
  | keyword_compat
//  | keyword_expr_uncompat
  | keyword_table_uncompat
//  | keyword_select_uncompat
  | keyword_alter_uncompat
  | keyword_in_uncompat
  | keyword_window_uncompat
  | keyword_hint_uncompat
;

id_hint:
    identifier
  | keyword_compat
  | keyword_expr_uncompat
  | keyword_table_uncompat
  | keyword_select_uncompat
  | keyword_alter_uncompat
  | keyword_in_uncompat
  | keyword_window_uncompat
//  | keyword_hint_uncompat
;

id_as_compat: identifier | keyword_as_compat;

// ANSI-aware versions of various identifiers with support double-quoted identifiers when PRAGMA AnsiQuotedIdentifiers; is present
an_id: id | STRING_VALUE;
an_id_or_type: id_or_type | STRING_VALUE;
an_id_schema: id_schema | STRING_VALUE;
an_id_expr: id_expr | STRING_VALUE;
an_id_expr_in: id_expr_in | STRING_VALUE;
an_id_window: id_window | STRING_VALUE;
an_id_table: id_table | STRING_VALUE;
an_id_without: id_without | STRING_VALUE;
an_id_hint: id_hint | STRING_VALUE;
an_id_pure: identifier | STRING_VALUE;
an_id_as_compat: id_as_compat | STRING_VALUE;

view_name: an_id | PRIMARY KEY;

opt_id_prefix: (an_id DOT)?;
cluster_expr: (an_id COLON)? (pure_column_or_named | ASTERISK);

id_or_type: id | type_id;
opt_id_prefix_or_type: (an_id_or_type DOT)?;
id_or_at: COMMAT? an_id_or_type;
id_table_or_type: an_id_table | type_id;
id_table_or_at: COMMAT? id_table_or_type;

keyword:
    keyword_compat
  | keyword_expr_uncompat
  | keyword_table_uncompat
  | keyword_select_uncompat
  | keyword_alter_uncompat
  | keyword_in_uncompat
  | keyword_window_uncompat
  | keyword_hint_uncompat
;

keyword_expr_uncompat:
    ASYMMETRIC
  | BETWEEN
  | BITCAST
  | CASE
  | CAST
  | CUBE
  | CURRENT_DATE
  | CURRENT_TIME
  | CURRENT_TIMESTAMP
  | EMPTY_ACTION
  | EXISTS
  | FROM
  | FULL
  | HOP
  | JSON_EXISTS
  | JSON_VALUE
  | JSON_QUERY
  | NOT
  | NULL
  | PROCESS
  | REDUCE
  | RETURN
  | RETURNING
  | ROLLUP
  | SELECT
  | SYMMETRIC
  | UNBOUNDED
  | WHEN
  | WHERE
;

keyword_table_uncompat:
    ANY
  | ERASE
  | STREAM
;

keyword_select_uncompat:
    ALL
  | AS
  | ASSUME
  | DISTINCT
  | EXCEPT
  | HAVING
  | INTERSECT
  | LIMIT
  | UNION
  | WINDOW
  | WITHOUT
;

keyword_alter_uncompat:
    COLUMN
;

keyword_in_uncompat:
    COMPACT
;

keyword_window_uncompat:
    GROUPS
  | RANGE
  | ROWS
;

keyword_hint_uncompat:
    SCHEMA
  | COLUMNS
;

keyword_as_compat:
    ABORT
  | ACTION
  | ADD
  | AFTER
  | ALTER
  | ANALYZE
  | AND
  | ANSI
  | ARRAY
  | ASC
  | ASYNC
  | AT
  | ATTACH
  | ATTRIBUTES
  | AUTOINCREMENT
  | BACKUP
  | BEFORE
  | BEGIN
  | BERNOULLI
  | BY
  | CASCADE
  | CHANGEFEED
  | CHECK
  | CLASSIFIER
  // | COLLATE
  | COLLECTION
  | COMMIT
  | CONDITIONAL
  | CONFLICT
  | CONNECT
  | CONSTRAINT
  | CONSUMER
  | COVER
  | CREATE
  // | CROSS
  | CURRENT
  | DATA
  | DATABASE
  | DECIMAL
  | DECLARE
  | DEFAULT
  | DEFERRABLE
  | DEFERRED
  // | DEFINE
  | DELETE
  | DESC
  | DESCRIBE
  | DETACH
  | DIRECTORY
  | DISABLE
  | DISCARD
  // | DO
  | DROP
  | EACH
  | ELSE
  | EMPTY
  | ENCRYPTED
  | END
  | ERROR
  | ESCAPE
  | EVALUATE
  | EXCLUDE
  // | EXCLUSION
  | EXCLUSIVE
  | EXPLAIN
  | EXPORT
  | EXTERNAL
  | FAIL
  | FAMILY
  | FILTER
  | FIRST
  | FLATTEN
  | FOLLOWING
  | FOR
  | FOREIGN
  | FUNCTION
  | GLOB
  | GLOBAL
  | GRANT
  | GROUP
  | GROUPING
  | HASH
  | IF
  | IGNORE
  | ILIKE
  | IMMEDIATE
  | IMPORT
  | IN
  | INCREMENT
  | INCREMENTAL
  | INDEX
  | INDEXED
  | INHERITS
  | INITIAL
  | INITIALLY
  // | INNER
  | INSERT
  | INSTEAD
  | INTO
  | IS
  // | ISNULL
  // | JOIN
  // | KEY
  | LAST
  // | LEFT
  | LEGACY
  | LIKE
  | LOCAL
  | MANAGE
  | MATCH
  | MATCHES
  | MATCH_RECOGNIZE
  | MEASURES
  | MICROSECONDS
  | MILLISECONDS
  | MODIFY
  | NANOSECONDS
  // | NATURAL
  | NEXT
  | NO
  // | NOTNULL
  | NULLS
  | OBJECT
  | OF
  | OFFSET
  | OMIT
  // | ON
  | ONE
  | ONLY
  | OPTION
  | OR
  | ORDER
  | OTHERS
  // | OUTER
  // | OVER
  | PARALLEL
  | PARTITION
  | PASSING
  | PASSWORD
  | PAST
  | PATTERN
  | PER
  | PERMUTE
  | PLAN
  | POOL
  | PRAGMA
  | PRECEDING
  // | PRESORT
  | PRIMARY
  | PRIVILEGES
  | QUERY
  | QUEUE
  | RAISE
//  | READ
  | REFERENCES
  | REGEXP
  | REINDEX
  | RELEASE
  | REMOVE
  | RENAME
  | REPLACE
  | REPLICATION
  | RESET
  | RESPECT
  | RESTART
  | RESTORE
  | RESTRICT
  // | RESULT
  | REVERT
  | REVOKE
  // | RIGHT
  | RLIKE
  | ROLLBACK
  | ROW
  // | SAMPLE
  | SAVEPOINT
  | SECONDS
  | SEEK
  // | SEMI
  | SETS
  | SHOW
  | TSKIP
  | SEQUENCE
  | SOURCE
  | START
  | SUBQUERY
  | SUBSET
  | SYMBOLS
  | SYNC
  | SYSTEM
  | TABLE
  | TABLES
  | TABLESAMPLE
  | TABLESTORE
  | TEMP
  | TEMPORARY
  | THEN
  | TIES
  | TO
  | TOPIC
  | TRANSACTION
  | TRIGGER
  | TYPE
  | UNCONDITIONAL
  | UNIQUE
  | UNKNOWN
  | UNMATCHED
  | UPDATE
  | UPSERT
  | USE
  | USER
//  | USING
  | VACUUM
  | VALUES
//  | VIEW
  | VIRTUAL
//  | WITH
  | WRAPPER
//  | WRITE
  | XOR
;

// insert new keyword into keyword_as_compat also
keyword_compat: (
    ABORT
  | ACTION
  | ADD
  | AFTER
  | ALTER
  | ANALYZE
  | AND
  | ANSI
  | ARRAY
  | ASC
  | ASYNC
  | AT
  | ATTACH
  | ATTRIBUTES
  | AUTOINCREMENT
  | BACKUP
  | BEFORE
  | BEGIN
  | BERNOULLI
  | BY
  | CASCADE
  | CHANGEFEED
  | CHECK
  | CLASSIFIER
  | COLLATE
  | COLLECTION
  | COMMIT
  | CONDITIONAL
  | CONFLICT
  | CONNECT
  | CONSTRAINT
  | CONSUMER
  | COVER
  | CREATE
  | CROSS
  | CURRENT
  | DATA
  | DATABASE
  | DECIMAL
  | DECLARE
  | DEFAULT
  | DEFERRABLE
  | DEFERRED
  | DEFINE
  | DELETE
  | DESC
  | DESCRIBE
  | DETACH
  | DIRECTORY
  | DISABLE
  | DISCARD
  | DO
  | DROP
  | EACH
  | ELSE
  | EMPTY
  | ENCRYPTED
  | END
  | ERROR
  | ESCAPE
  | EVALUATE
  | EXCLUDE
  | EXCLUSION
  | EXCLUSIVE
  | EXPLAIN
  | EXPORT
  | EXTERNAL
  | FAIL
  | FAMILY
  | FILTER
  | FIRST
  | FLATTEN
  | FOLLOWING
  | FOR
  | FOREIGN
  | FUNCTION
  | GLOB
  | GLOBAL
  | GRANT
  | GROUP
  | GROUPING
  | HASH
  | IF
  | IGNORE
  | ILIKE
  | IMMEDIATE
  | IMPORT
  | IN
  | INCREMENT
  | INCREMENTAL
  | INDEX
  | INDEXED
  | INHERITS
  | INITIAL
  | INITIALLY
  | INNER
  | INSERT
  | INSTEAD
  | INTO
  | IS
  | ISNULL
  | JOIN
  | KEY
  | LAST
  | LEFT
  | LEGACY
  | LIKE
  | LOCAL
  | MANAGE
  | MATCH
  | MATCHES
  | MATCH_RECOGNIZE
  | MEASURES
  | MICROSECONDS
  | MILLISECONDS
  | MODIFY
  | NANOSECONDS
  | NATURAL
  | NEXT
  | NO
  | NOTNULL
  | NULLS
  | OBJECT
  | OF
  | OFFSET
  | OMIT
  | ON
  | ONE
  | ONLY
  | OPTION
  | OR
  | ORDER
  | OTHERS
  | OUTER
  | OVER
  | PARALLEL
  | PARTITION
  | PASSING
  | PASSWORD
  | PAST
  | PATTERN
  | PER
  | PERMUTE
  | PLAN
  | POOL
  | PRAGMA
  | PRECEDING
  | PRESORT
  | PRIMARY
  | PRIVILEGES
  | QUERY
  | QUEUE
  | RAISE
//  | READ
  | REFERENCES
  | REGEXP
  | REINDEX
  | RELEASE
  | REMOVE
  | RENAME
  | REPLACE
  | REPLICATION
  | RESET
  | RESPECT
  | RESTART
  | RESTORE
  | RESTRICT
  | RESULT
  | REVERT
  | REVOKE
  | RIGHT
  | RLIKE
  | ROLLBACK
  | ROW
  | SAMPLE
  | SAVEPOINT
  | SECONDS
  | SEEK
  | SEMI
  | SETS
  | SHOW
  | TSKIP
  | SEQUENCE
  | SOURCE
  | START
  | SUBQUERY
  | SUBSET
  | SYMBOLS
  | SYNC
  | SYSTEM
  | TABLE
  | TABLES
  | TABLESAMPLE
  | TABLESTORE
  | TEMP
  | TEMPORARY
  | THEN
  | TIES
  | TO
  | TOPIC
  | TRANSACTION
  | TRIGGER
  | TYPE
  | UNCONDITIONAL
  | UNIQUE
  | UNKNOWN
  | UNMATCHED
  | UPDATE
  | UPSERT
  | USE
  | USER
  | USING
  | VACUUM
  | VALUES
  | VIEW
  | VIRTUAL
  | WITH
  | WRAPPER
//  | WRITE
  | XOR
  );

type_id:
    OPTIONAL
  | TUPLE
  | STRUCT
  | VARIANT
  | LIST
//  | STREAM
  | FLOW
  | DICT
  | SET
  | ENUM
  | RESOURCE
  | TAGGED
  | CALLABLE
;

bool_value: (TRUE | FALSE);
real: REAL;
integer: DIGITS | INTEGER_VALUE;

//
// Lexer
//

EQUALS:        '=';
EQUALS2:       '==';
NOT_EQUALS:    '!=';
NOT_EQUALS2:   '<>';
LESS:          '<';
LESS_OR_EQ:    '<=';
GREATER:       '>';
GREATER_OR_EQ: '>=';
SHIFT_LEFT:    '<<';
ROT_LEFT:      '|<<';
AMPERSAND:     '&';
PIPE:          '|';
DOUBLE_PIPE:   '||';
STRUCT_OPEN:   '<|';
STRUCT_CLOSE:  '|>';
PLUS:          '+';
MINUS:         '-';
TILDA:         '~';
ASTERISK:      '*';
SLASH:         '/';
PERCENT:       '%';
SEMICOLON:     ';';
DOT:           '.';
COMMA:         ',';
LPAREN:        '(';
RPAREN:        ')';
QUESTION:      '?';
COLON:         ':';
COMMAT:        '@';
DOLLAR:        '$';
LBRACE_CURLY:  '{';
RBRACE_CURLY:  '}';
CARET:         '^';
NAMESPACE:     '::';
ARROW:         '->';
RBRACE_SQUARE: ']';
LBRACE_SQUARE: '['; // pair ]

fragment BACKSLASH:     '\\';
fragment QUOTE_DOUBLE:  '"';
fragment QUOTE_SINGLE: '\'';
fragment BACKTICK:      '`';
fragment DOUBLE_COMMAT: '@@';

// http://www.antlr.org/wiki/pages/viewpage.action?pageId=1782
fragment A:('a'|'A');
fragment B:('b'|'B');
fragment C:('c'|'C');
fragment D:('d'|'D');
fragment E:('e'|'E');
fragment F:('f'|'F');
fragment G:('g'|'G');
fragment H:('h'|'H');
fragment I:('i'|'I');
fragment J:('j'|'J');
fragment K:('k'|'K');
fragment L:('l'|'L');
fragment M:('m'|'M');
fragment N:('n'|'N');
fragment O:('o'|'O');
fragment P:('p'|'P');
fragment Q:('q'|'Q');
fragment R:('r'|'R');
fragment S:('s'|'S');
fragment T:('t'|'T');
fragment U:('u'|'U');
fragment V:('v'|'V');
fragment W:('w'|'W');
fragment X:('x'|'X');
fragment Y:('y'|'Y');
fragment Z:('z'|'Z');

ABORT: A B O R T;
ACTION: A C T I O N;
ADD: A D D;
AFTER: A F T E R;
ALL: A L L;
ALTER: A L T E R;
ANALYZE: A N A L Y Z E;
AND: A N D;
ANSI: A N S I;
ANY: A N Y;
ARRAY: A R R A Y;
AS: A S;
ASC: A S C;
ASSUME: A S S U M E;
ASYMMETRIC: A S Y M M E T R I C;
ASYNC: A S Y N C;
AT: A T;
ATTACH: A T T A C H;
ATTRIBUTES: A T T R I B U T E S;
AUTOINCREMENT: A U T O I N C R E M E N T;
AUTOMAP: A U T O M A P;
BACKUP: B A C K U P;
COLLECTION: C O L L E C T I O N;
BEFORE: B E F O R E;
BEGIN: B E G I N;
BERNOULLI: B E R N O U L L I;
BETWEEN: B E T W E E N;
BITCAST: B I T C A S T;
BY: B Y;
CALLABLE: C A L L A B L E;
CASCADE: C A S C A D E;
CASE: C A S E;
CAST: C A S T;
CHANGEFEED: C H A N G E F E E D;
CHECK: C H E C K;
CLASSIFIER: C L A S S I F I E R;
COLLATE: C O L L A T E;
COLUMN: C O L U M N;
COLUMNS: C O L U M N S;
COMMIT: C O M M I T;
COMPACT: C O M P A C T;
CONDITIONAL: C O N D I T I O N A L;
CONFLICT: C O N F L I C T;
CONNECT: C O N N E C T;
CONSTRAINT: C O N S T R A I N T;
CONSUMER: C O N S U M E R;
COVER: C O V E R;
CREATE: C R E A T E;
CROSS: C R O S S;
CUBE: C U B E;
CURRENT: C U R R E N T;
CURRENT_DATE: C U R R E N T '_' D A T E;
CURRENT_TIME: C U R R E N T '_' T I M E;
CURRENT_TIMESTAMP: C U R R E N T '_' T I M E S T A M P;
DATA: D A T A;
DATABASE: D A T A B A S E;
DECIMAL: D E C I M A L;
DECLARE: D E C L A R E;
DEFAULT: D E F A U L T;
DEFERRABLE: D E F E R R A B L E;
DEFERRED: D E F E R R E D;
DEFINE: D E F I N E;
DELETE: D E L E T E;
DESC: D E S C;
DESCRIBE: D E S C R I B E;
DETACH: D E T A C H;
DICT: D I C T;
DIRECTORY: D I R E C T O R Y;
DISABLE: D I S A B L E;
DISCARD: D I S C A R D;
DISTINCT: D I S T I N C T;
DO: D O;
DROP: D R O P;
// TODO: fix sql formatter and drop EACH
EACH: E A C H;
ELSE: E L S E;
EMPTY: E M P T Y;
EMPTY_ACTION: E M P T Y '_' A C T I O N;
ENCRYPTED: E N C R Y P T E D;
END: E N D;
ENUM: E N U M;
ERASE: E R A S E;
ERROR: E R R O R;
ESCAPE: E S C A P E;
EVALUATE: E V A L U A T E;
EXCEPT: E X C E P T;
EXCLUDE: E X C L U D E;
EXCLUSION: E X C L U S I O N;
EXCLUSIVE: E X C L U S I V E;
EXISTS: E X I S T S;
EXPLAIN: E X P L A I N;
EXPORT: E X P O R T;
EXTERNAL: E X T E R N A L;
FAIL: F A I L;
FALSE: F A L S E;
FAMILY: F A M I L Y;
FILTER: F I L T E R;
FIRST: F I R S T;
FLATTEN: F L A T T E N;
FLOW: F L O W;
FOLLOWING: F O L L O W I N G;
FOR: F O R;
FOREIGN: F O R E I G N;
FROM: F R O M;
FULL: F U L L;
FUNCTION: F U N C T I O N;
GLOB: G L O B;
GLOBAL: G L O B A L;
GRANT: G R A N T;
GROUP: G R O U P;
GROUPING: G R O U P I N G;
GROUPS: G R O U P S;
HASH: H A S H;
HAVING: H A V I N G;
HOP: H O P;
IF: I F;
IGNORE: I G N O R E;
ILIKE: I L I K E;
IMMEDIATE: I M M E D I A T E;
IMPORT: I M P O R T;
IN: I N;
INCREMENT: I N C R E M E N T;
INCREMENTAL: I N C R E M E N T A L;
INDEX: I N D E X;
INDEXED: I N D E X E D;
INHERITS: I N H E R I T S;
INITIAL: I N I T I A L;
INITIALLY: I N I T I A L L Y;
INNER: I N N E R;
INSERT: I N S E R T;
INSTEAD: I N S T E A D;
INTERSECT: I N T E R S E C T;
INTO: I N T O;
IS: I S;
ISNULL: I S N U L L;
JOIN: J O I N;
JSON_EXISTS: J S O N '_' E X I S T S;
JSON_QUERY: J S O N '_' Q U E R Y;
JSON_VALUE: J S O N '_' V A L U E;
KEY: K E Y;
LAST: L A S T;
LEFT: L E F T;
LEGACY: L E G A C Y;
LIKE: L I K E;
LIMIT: L I M I T;
LIST: L I S T;
LOCAL: L O C A L;
MANAGE: M A N A G E;
MATCH: M A T C H;
MATCHES: M A T C H E S;
MATCH_RECOGNIZE: M A T C H '_' R E C O G N I Z E;
MEASURES: M E A S U R E S;
MICROSECONDS: M I C R O S E C O N D S;
MILLISECONDS: M I L L I S E C O N D S;
MODIFY: M O D I F Y;
NANOSECONDS: N A N O S E C O N D S;
NATURAL: N A T U R A L;
NEXT: N E X T;
NO: N O;
NOT: N O T;
NOTNULL: N O T N U L L;
NULL: N U L L;
NULLS: N U L L S;
OBJECT: O B J E C T;
OF: O F;
OFFSET: O F F S E T;
OMIT: O M I T;
ON: O N;
ONE: O N E;
ONLY: O N L Y;
OPTION: O P T I O N;
OPTIONAL: O P T I O N A L;
OR: O R;
ORDER: O R D E R;
OTHERS: O T H E R S;
OUTER: O U T E R;
OVER: O V E R;
PARALLEL: P A R A L L E L;
PARTITION: P A R T I T I O N;
PASSING: P A S S I N G;
PASSWORD: P A S S W O R D;
PAST: P A S T;
PATTERN: P A T T E R N;
PER: P E R;
PERMUTE: P E R M U T E;
PLAN: P L A N;
POOL: P O O L;
PRAGMA: P R A G M A;
PRECEDING: P R E C E D I N G;
PRESORT: P R E S O R T;
PRIMARY: P R I M A R Y;
PRIVILEGES: P R I V I L E G E S;
PROCESS: P R O C E S S;
QUERY: Q U E R Y;
QUEUE: Q U E U E;
RAISE: R A I S E;
RANGE: R A N G E;
//READ: R E A D;
REDUCE: R E D U C E;
REFERENCES: R E F E R E N C E S;
REGEXP: R E G E X P;
REINDEX: R E I N D E X;
RELEASE: R E L E A S E;
REMOVE: R E M O V E;
RENAME: R E N A M E;
REPEATABLE: R E P E A T A B L E;
REPLACE: R E P L A C E;
REPLICATION: R E P L I C A T I O N;
RESET: R E S E T;
RESOURCE: R E S O U R C E;
RESPECT: R E S P E C T;
RESTART: R E S T A R T;
RESTORE: R E S T O R E;
RESTRICT: R E S T R I C T;
RESULT: R E S U L T;
RETURN: R E T U R N;
RETURNING: R E T U R N I N G;
REVERT: R E V E R T;
REVOKE: R E V O K E;
RIGHT: R I G H T;
RLIKE: R L I K E;
ROLLBACK: R O L L B A C K;
ROLLUP: R O L L U P;
ROW: R O W;
ROWS: R O W S;
SAMPLE: S A M P L E;
SAVEPOINT: S A V E P O I N T;
SCHEMA: S C H E M A;
SECONDS: S E C O N D S;
SEEK: S E E K;
SELECT: S E L E C T;
SEMI: S E M I;
SET: S E T;
SETS: S E T S;
SHOW: S H O W;
TSKIP: S K I P;
SEQUENCE: S E Q U E N C E;
SOURCE: S O U R C E;
START: S T A R T;
STREAM: S T R E A M;
STRUCT: S T R U C T;
SUBQUERY: S U B Q U E R Y;
SUBSET: S U B S E T;
SYMBOLS: S Y M B O L S;
SYMMETRIC: S Y M M E T R I C;
SYNC: S Y N C;
SYSTEM: S Y S T E M;
TABLE: T A B L E;
TABLES: T A B L E S;
TABLESAMPLE: T A B L E S A M P L E;
TABLESTORE: T A B L E S T O R E;
TAGGED: T A G G E D;
TEMP: T E M P;
TEMPORARY: T E M P O R A R Y;
THEN: T H E N;
TIES: T I E S;
TO: T O;
TOPIC: T O P I C;
TRANSACTION: T R A N S A C T I O N;
TRIGGER: T R I G G E R;
TRUE: T R U E;
TUPLE: T U P L E;
TYPE: T Y P E;
UNBOUNDED: U N B O U N D E D;
UNCONDITIONAL: U N C O N D I T I O N A L;
UNION: U N I O N;
UNIQUE: U N I Q U E;
UNKNOWN: U N K N O W N;
UNMATCHED: U N M A T C H E D;
UPDATE: U P D A T E;
UPSERT: U P S E R T;
USE: U S E;
USER: U S E R;
USING: U S I N G;
VACUUM: V A C U U M;
VALUES: V A L U E S;
VARIANT: V A R I A N T;
VIEW: V I E W;
VIRTUAL: V I R T U A L;
WHEN: W H E N;
WHERE: W H E R E;
WINDOW: W I N D O W;
WITH: W I T H;
WITHOUT: W I T H O U T;
WRAPPER: W R A P P E R;
//WRITE: W R I T E;
XOR: X O R;

// YQL Default Lexer:
// GRAMMAR_STRING_CORE_SINGLE = ~('\'' | '\\') | ('\\' .)
// GRAMMAR_STRING_CORE_DOUBLE = ~('\'' | '\\') | ('\\' .)

// ANSI Lexer:
// GRAMMAR_STRING_CORE_SINGLE = ~QUOTE_SINGLE | (QUOTE_SINGLE QUOTE_SINGLE)
// GRAMMAR_STRING_CORE_DOUBLE = ~QUOTE_DOUBLE | (QUOTE_DOUBLE QUOTE_DOUBLE)

fragment STRING_CORE_SINGLE: ~('\'' | '\\') | ('\\' .);
fragment STRING_CORE_DOUBLE: ~('\'' | '\\') | ('\\' .);

fragment STRING_SINGLE: (QUOTE_SINGLE STRING_CORE_SINGLE* QUOTE_SINGLE);
fragment STRING_DOUBLE: (QUOTE_DOUBLE STRING_CORE_DOUBLE* QUOTE_DOUBLE);
fragment STRING_MULTILINE: (DOUBLE_COMMAT .*? DOUBLE_COMMAT)+ COMMAT?;

STRING_VALUE: ((STRING_SINGLE | STRING_DOUBLE | STRING_MULTILINE) (S | U | Y | J | P (T | B | V)?)?);

ID_PLAIN: ('a'..'z' | 'A'..'Z' | '_') ('a'..'z' | 'A'..'Z' | '_' | DIGIT)*;

fragment ID_QUOTED_CORE: '\\'. | '``' | ~('`' | '\\');
ID_QUOTED: BACKTICK ID_QUOTED_CORE* BACKTICK;

fragment DIGIT: '0'..'9';
fragment HEXDIGIT: '0'..'9' | 'a'..'f' | 'A'..'F';
fragment HEXDIGITS: '0' X HEXDIGIT+;
fragment OCTDIGITS: '0' O ('0'..'8')+;
fragment BINDIGITS: '0' B ('0' | '1')+;
fragment DECDIGITS: DIGIT+;
DIGITS: DECDIGITS | HEXDIGITS | OCTDIGITS | BINDIGITS;

// not all combinations of P/U with L/S/T/I/B/N are actually valid - this is resolved in sql.cpp
INTEGER_VALUE: DIGITS ((P | U)? (L | S | T | I | B | N)?);

fragment FLOAT_EXP : E (PLUS | MINUS)? DECDIGITS ;
REAL:
    (
        DECDIGITS DOT DIGIT* FLOAT_EXP?
    |   DECDIGITS FLOAT_EXP
//  |   DOT DECDIGITS FLOAT_EXP?    // Conflicts with tuple element access through DOT
    ) (F | P (F ('4'|'8') | N)?)?
    ;

BLOB: X QUOTE_SINGLE HEXDIGIT+ QUOTE_SINGLE;

// YQL Default Lexer:
// GRAMMAR_MULTILINE_COMMENT_CORE = .
// ANSI Lexer:
// GRAMMAR_MULTILINE_COMMENT_CORE = MULTILINE_COMMENT | .

fragment MULTILINE_COMMENT: '/*' ( . )*? '*/';
fragment LINE_COMMENT: '--' ~('\n'|'\r')* ('\r' '\n'? | '\n' | EOF);
WS: (' '|'\r'|'\t'|'\u000C'|'\n')->channel(HIDDEN);
COMMENT: (MULTILINE_COMMENT|LINE_COMMENT)->channel(HIDDEN);