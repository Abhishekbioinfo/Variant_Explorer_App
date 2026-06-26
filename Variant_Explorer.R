# 1. Auto-Install and Load Required Packages
required_packages <- c("shiny", "DT", "dplyr", "tools", "bslib", "shinyWidgets", "data.table")

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg)
  }
  library(pkg, character.only = TRUE)
}

# 2. GLOBAL CONFIGURATION
options(shiny.maxRequestSize = 1000 * 1024^2) 

cat("Loading Actionability TSV into memory...\n")
# Updated to the new file name
action_df <- fread("Actionability_AllData_v20_GRCh37.tsv", stringsAsFactors = FALSE)
setDT(action_df) # Convert to data.table for maximum processing speed

cat("Server Ready! Architecture: Lazy Loading with Fuzzy Matching.\n")

# 3. UI
ui <- fluidPage(class = "container-fluid",
                theme = bslib::bs_theme(version = 5, bootswatch = "flatly"),
                titlePanel(div("🧬 Clinical Genomic Variant & Actionability Explorer", style = "margin-bottom: 20px;")),
                
                sidebarLayout(
                  sidebarPanel(
                    width = 3,
                    h4("Data Upload"),
                    fileInput("upload_file", "Upload Primary Variant File (.csv)", accept = c(".csv")),
                    hr(),
                    h4("Search & Filter Criteria"),
                    shinyWidgets::virtualSelectInput("show_cols", "Select Columns:", choices = NULL, multiple = TRUE, search = TRUE, selectAllText = "Select All"),
                    selectizeInput("gene", "Gene Symbol:", choices = NULL, multiple = TRUE),
                    textInput("variant_id", "Variant ID:", placeholder = "Search ID..."),
                    textInput("vep_hgvsp", "VEP HGVSp:", placeholder = "Search HGVSp..."),
                    shinyWidgets::virtualSelectInput("vep_consequence", "VEP Consequence:", choices = NULL, multiple = TRUE, search = TRUE),
                    hr(),
                    sliderInput("total_score_slider", "Total Score Filter:", min = -20, max = 20, value = c(-20, 20)),
                    sliderInput("vep_af_slider", "VEP Allele Frequency (AF):", min = 0, max = 1, value = c(0, 1), step = 0.0001),
                    checkboxGroupInput("vep_impact", "VEP Impact Tier:", choices = c("HIGH", "MODERATE", "LOW", "MODIFIER"), selected = c("HIGH", "MODERATE", "MODIFIER"))
                  ),
                  
                  mainPanel(
                    width = 9,
                    conditionalPanel(
                      condition = "output.fileUploaded",
                      fluidRow(
                        column(4, uiOutput("kpi_total_variants")), 
                        column(4, uiOutput("kpi_high_impact")), 
                        column(4, uiOutput("kpi_max_score"))
                      ),
                      br(),
                      
                      # Table 1: Strictly Uploaded Variants
                      div(class = "card",
                          div(class = "card-header bg-primary text-white", h5(class = "mb-0", "1. Uploaded Variants (Click a row to query actionability)")),
                          div(class = "card-body", DTOutput("variantTable"))
                      ),
                      
                      br(),
                      
                      # Table 2: Fuzzy Matched Actionability Results
                      div(class = "card",
                          div(class = "card-header bg-dark text-white", h5(class = "mb-0", "2. Associated Drugs & Trials (Live Fuzzy Match Query)")),
                          div(class = "card-body", DTOutput("actionTable"))
                      )
                    ),
                    conditionalPanel(
                      condition = "!output.fileUploaded", 
                      div(class = "alert alert-info", "Please upload a CSV file to begin. The COSMIC Actionability database is loaded and waiting in memory.")
                    )
                  )
                )
)

# 4. SERVER
server <- function(input, output, session) {
  
  output$fileUploaded <- reactive({ return(!is.null(input$upload_file)) })
  outputOptions(output, 'fileUploaded', suspendWhenHidden = FALSE)
  
  # Strictly the uploaded variant file. NO JOINS.
  raw_data <- reactive({
    req(input$upload_file)
    df <- fread(input$upload_file$datapath, data.table = FALSE, stringsAsFactors = FALSE)
    
    if ("Total_Score" %in% colnames(df)) df$Total_Score <- as.numeric(df$Total_Score)
    if ("VEP_AF" %in% colnames(df)) {
      df$VEP_AF <- suppressWarnings(as.numeric(df$VEP_AF))
      df$VEP_AF[is.na(df$VEP_AF)] <- 0
    } else { df$VEP_AF <- 0 }
    
    return(df)
  })
  
  # --- UI Sync & Filters ---
  observe({
    req(input$upload_file)
    df <- raw_data()
    default_cols <- intersect(c("GENE", "VEP_SYMBOL", "VARIANT_ID", "VEP_HGVSp", "VEP_Consequence", "VEP_IMPACT", "CHROM", "POS", "REF", "ALT", "VEP_AF"), colnames(df))
    
    shinyWidgets::updateVirtualSelect(inputId = "show_cols", choices = colnames(df), selected = default_cols)
    
    gene_col <- if("VEP_SYMBOL" %in% colnames(df)) "VEP_SYMBOL" else "GENE"
    if(gene_col %in% colnames(df)) updateSelectizeInput(session, "gene", choices = sort(unique(df[[gene_col]])))
    
    if ("VEP_Consequence" %in% colnames(df)) {
      shinyWidgets::updateVirtualSelect(inputId = "vep_consequence", choices = sort(unique(df$VEP_Consequence)))
    }
  })
  
  filtered_data <- reactive({
    req(input$upload_file, input$total_score_slider, input$vep_af_slider)
    df <- raw_data()
    gene_col <- if("VEP_SYMBOL" %in% colnames(df)) "VEP_SYMBOL" else "GENE"
    
    if (!is.null(input$gene)) df <- df %>% filter(.data[[gene_col]] %in% input$gene)
    if (trimws(input$variant_id) != "") df <- df %>% filter(grepl(trimws(input$variant_id), VARIANT_ID, ignore.case = TRUE))
    if (trimws(input$vep_hgvsp) != "") df <- df %>% filter(grepl(trimws(input$vep_hgvsp), VEP_HGVSp, ignore.case = TRUE))
    if (!is.null(input$vep_consequence) && length(input$vep_consequence) > 0) df <- df %>% filter(VEP_Consequence %in% input$vep_consequence)
    
    if ("Total_Score" %in% colnames(df)) df <- df %>% filter(Total_Score >= input$total_score_slider[1] & Total_Score <= input$total_score_slider[2])
    if ("VEP_AF" %in% colnames(df)) df <- df %>% filter(VEP_AF >= input$vep_af_slider[1] & VEP_AF <= input$vep_af_slider[2])
    if (!is.null(input$vep_impact) && "VEP_IMPACT" %in% colnames(df)) df <- df %>% filter(VEP_IMPACT %in% input$vep_impact)
    
    return(df)
  })
  
  # KPI Updates
  output$kpi_total_variants <- renderUI({ 
    req(input$upload_file)
    div(class = "card bg-primary text-white p-3 mb-2", h5("Total Variants"), h2(nrow(filtered_data()))) 
  })
  output$kpi_high_impact <- renderUI({ 
    req(input$upload_file)
    div(class = "card bg-warning text-white p-3 mb-2", h5("High Impact"), h2(nrow(filtered_data() %>% filter(VEP_IMPACT == "HIGH")))) 
  })
  output$kpi_max_score <- renderUI({ 
    req(input$upload_file)
    max_val <- if("Total_Score" %in% colnames(filtered_data())) max(filtered_data()$Total_Score, na.rm=TRUE) else max(filtered_data()$VEP_AF, na.rm=TRUE)
    div(class = "card bg-success text-white p-3 mb-2", h5(if("Total_Score" %in% colnames(filtered_data())) "Max Score" else "Max AF"), h2(round(ifelse(is.infinite(max_val), 0, max_val), 4))) 
  })
  
  # --- Table 1: Uploaded Variants ---
  output$variantTable <- renderDT({
    req(input$show_cols)
    datatable(
      filtered_data() %>% select(all_of(input$show_cols)), 
      selection = 'single', # Allows clicking to trigger the fuzzy lookup
      rownames = FALSE, 
      options = list(scrollX = TRUE, pageLength = 5, dom = 'Bfrtip', buttons = list('copy', 'csv')), 
      class = 'cell-border stripe hover'
    )
  })
  
  # --- Table 2: Fuzzy Actionability Query ---
  output$actionTable <- renderDT({
    req(input$variantTable_rows_selected)
    
    # 1. Get selected row data and isolate the gene
    selected_row <- filtered_data()[input$variantTable_rows_selected, ]
    gene_col <- if("VEP_SYMBOL" %in% colnames(selected_row)) "VEP_SYMBOL" else "GENE"
    target_gene <- selected_row[[gene_col]]
    
    req(target_gene)
    
    # 2. Safely identify the MUTATION_REMARK column
    mut_col <- if ("MUTATION_REMARK" %in% colnames(action_df)) "MUTATION_REMARK" else grep("MUTATION", colnames(action_df), value = TRUE)[1]
    
    # 3. FAST FUZZY MATCH
    # Using data.table grepl to scan the identified MUTATION column for the clicked Gene
    drug_info <- action_df[grepl(target_gene, action_df[[mut_col]], ignore.case = TRUE)]
    
    # 4. Clean up columns based on the new Actionability TSV format
    display_trials <- drug_info %>%
      select(
        Mutation_Remark = all_of(mut_col),
        any_of(c("DISEASE", "DRUG_COMBINATION", "DEVELOPMENT_STATUS", "TRIAL_STATUS", "TRIAL_ID", "SOURCE"))
      ) %>%
      distinct()
    
    datatable(
      display_trials, 
      rownames = FALSE, 
      filter = 'top',
      options = list(scrollX = TRUE, pageLength = 5, dom = 'rtip'), 
      class = 'cell-border stripe hover',
      caption = htmltools::tags$caption(
        style = 'caption-side: top; text-align: left; color: black; font-weight: bold;',
        paste("Clinical Data (Fuzzy Match) for Gene:", target_gene)
      )
    )
  })
}

shinyApp(ui, server)