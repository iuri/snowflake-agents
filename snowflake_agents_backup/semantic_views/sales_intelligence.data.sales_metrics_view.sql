create or replace semantic view SALES_METRICS_VIEW
	tables (
		SALES_INTELLIGENCE.DATA.SALES_METRICS comment='The table contains records of sales deals and their associated performance metrics. Each record represents a single deal and includes details about the customer, assigned sales representative, product line, deal value, and progression through the sales pipeline including closure outcomes.'
	)
	facts (
		SALES_METRICS.DEAL_VALUE as DEAL_VALUE comment='The monetary value associated with a sales deal.' sample_values ('120000', '75000', '25000')
	)
	dimensions (
		SALES_METRICS.CUSTOMER_NAME as CUSTOMER_NAME with synonyms=('account_holder','account_name','buyer_identifier','buyer_name','client_identifier','client_label','client_name','customer_identifier','customer_title','purchaser_name') comment='The name of the customer or organization associated with the sales record.' sample_values ('TechCorp Inc', 'SecureBank Ltd', 'SmallBiz Solutions'),
		SALES_METRICS.DEAL_ID as DEAL_ID comment='Unique identifier assigned to each sales deal.' sample_values ('DEAL003', 'DEAL001', 'DEAL002'),
		SALES_METRICS.PRODUCT_LINE as PRODUCT_LINE with synonyms=('merchandise line','product category','product family','product group','product portfolio','product range','product segment','product series','product suite','product type') comment='The name of the product line associated with a sales metric entry.' sample_values ('Enterprise Suite', 'Basic Package', 'Premium Security'),
		SALES_METRICS.SALES_REP as SALES_REP with synonyms=('account_executive','account_manager','sales_agent','sales_associate','sales_consultant','sales_officer','sales_person','sales_representative','sales_team_member','territory_manager') comment='The name of the sales representative associated with the record.' sample_values ('Sarah Johnson', 'Mike Chen', 'Rachel Torres'),
		SALES_METRICS.SALES_STAGE as SALES_STAGE with synonyms=('deal_phase','deal_progress','deal_status','opportunity_phase','opportunity_stage','pipeline_phase','pipeline_stage','sales_cycle_stage','sales_funnel_stage','sales_phase') comment='The current stage of a sales opportunity in the sales pipeline.' sample_values ('Closed', 'Lost', 'Pending'),
		SALES_METRICS.WIN_STATUS as WIN_STATUS with synonyms=('closure_status','deal_outcome','deal_result','deal_won','success_indicator','success_status','victory_flag','win_flag','winning_flag','won_indicator') comment='Indicates whether a sale or opportunity was won.' sample_values ('TRUE', 'FALSE'),
		SALES_METRICS.CLOSE_DATE as CLOSE_DATE comment='The date on which a sale or deal was closed.' sample_values ('2024-02-15', '2024-01-30', '2024-02-01')
	)
	metrics (
		SALES_METRICS.AVERAGE_DEAL_SIZE as AVG(deal_value) comment='calculates the average of deal values',
		SALES_METRICS.TOTAL_DEALS as count(*) comment='counts the total number of deals',
		SALES_METRICS.WIN_RATE as SUM(CASE WHEN win_status = TRUE THEN 1 ELSE 0 END) / COUNT(*) comment='Calculates win deal divided by total deals'
	)
	with extension (CA='{"tables":[{"name":"SALES_METRICS","dimensions":[{"name":"CUSTOMER_NAME"},{"name":"DEAL_ID"},{"name":"PRODUCT_LINE"},{"name":"SALES_REP"},{"name":"SALES_STAGE"},{"name":"WIN_STATUS"}],"facts":[{"name":"DEAL_VALUE"}],"metrics":[{"name":"average_deal_size"},{"name":"total_deals"},{"name":"win_rate"}],"time_dimensions":[{"name":"CLOSE_DATE"}]}]}');