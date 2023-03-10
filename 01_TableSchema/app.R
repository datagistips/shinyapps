library(shiny)
library(jsonlite)
library(tidyverse)
library(DT)
library(glue)
library(uuid)

# Default URL
default_url <- function(schema_url) {
  j <- jsonlite::fromJSON(schema_url)
  j$schema_url
}

schema_url <- default_url("default.json")

# ID Field
default_id <- function(schema_url) {
  j <- jsonlite::fromJSON(schema_url)
  
  # If primary key specified, use it
  if("primaryKey" %in% names(j)) return(j$primaryKey)
  
  # If not, try to access it through the schema config file (if it exists)
  schema_name <- j$name
  config_file <- glue("{schema_name}.json")
  if(file.exists(config_file)) {
    conf <- jsonlite::fromJSON(config_file)
    id <- conf$id
    return(id)
  } else {
    return()
  }
}

# > FUNCTIONS ----
get_fields <- function(j) {
  fields <- j$fields
  fields
}

get_ui <- function(field, id = "id") {
  # Gets the UI for a specific field
  
  name <- field$name
  example <- field$example
  description <- field$description
  constraints <- field$constraints
  type <- field$type
  
  ui_id <- glue("ui__{name}")  # Each UI element will be identified like this : ui__id, ui__date_creation with doubled '_'
  
  # REQUIRED
  # If required, we add an asterisk (*) to the field name, i.e. id*
  if(is.na(constraints$required)) {
    name_display <- name
  } else {
    true_values <- c("true", "TRUE", "True", "1")
    false_values <- c("false", "FALSE", "False", "0")
    required <- constraints$required %in% true_values
    if(required) {
      name_display <- glue("{name}*")
    } else {
      name_display <- names
    }
  }
  
  # TEXT OUTPUT
  if(field$type == "string") {
    # String field may have constraints, like specific list of values
    enum <- constraints$enum[[1]]
    if(is.null(enum)) {
      ui <- textInput(ui_id, name_display, placeholder = example)
    } else {
      names(enum) <- enum
      ui <- selectInput(ui_id, name_display, choices = enum, multiple = FALSE)
    }
    
    # UUID
    if(name == id & field$type == "string") {
      ui <- fluidRow(column(9, ui),
                     column(3, actionButton("uuid", "Generate uuid", icon=icon("fingerprint")), style="margin-top:22px;"))
    }
  }
  
  # NUMERIC INPUT
  if(field$type == "integer") {
    min_value <- constraints$minimum
    max_value <- constraints$maximum
    
    # If min and max are null, min  = 0, and no max is specified
    if(is.null(min_value) & is.null(max_value)) {
      ui <- numericInput(ui_id, name_display, value = 0)
    }
    # If min is not null and max is null, no max is specified
    if(!is.null(min_value) & is.null(max_value)) {
      ui <- numericInput(ui_id, name_display, value = min_value, min = min_value)
    }
    # If min is not null and max is not null, min and max are specified
    if(!is.null(min_value) & !is.null(max_value)) {
      ui <- numericInput(ui_id, name_display, value = min_value, min = min_value, max = max_value)
    }
  }
  
  # DATE INPUT
  if(field$type == "date") {
    ui <- dateInput(ui_id, name_display, value = Sys.Date()) # We take "now is the time" date
  }
  
  # HELP TEXT
  ui <- tagList(ui, 
                helpText(description, 
                         "Ex. : ", example)) # We add the description as a help text to fill the information
  
  return(ui)
}

get_uis <- function(fields, id = "id") {
  # Gets the UI elements
  
  uis <- vector(mode = "list")
  # List all fields and calculate the UI element
  for(i in 1:nrow(fields)) {
    field <- fields[i, ]
    ui <- get_ui(field, id)
    uis[[i]] <- ui
  }
  # Assign the field name to the list of UIs
  names(uis) <- fields$name
  return(uis)
}

get_description <- function(j) {
  # Gets the schema description
  
  # Name, title, description and contributors
  # (you could pick more description elements from the schema)
  name <- j$name
  title <- j$title
  description <- j$description
  contributors <- j$contributors
  contributors <- glue("{contributors$title} ({contributors$email}") %>% paste(collapse=", ")
  
  tagList(tags$p(tags$strong(glue("{title} ({name})"))),
          tags$p(description),
          tags$p("Authors : ", contributors))
}

# NOW is the app !

# > UI ----
ui <- fluidPage(
    
    # Title panel
    titlePanel("TableSchema example"),
    
    # Some description
    tags$p("This apps reads a ", tags$a(href="https://specs.frictionlessdata.io/table-schema/", "TableSchema"), ", generates a form to fill in data that respects the schema.", "It is an adaptation of Etalab", tags$a(href="https://github.com/etalab/csv-gg", "CSV-GG")),
    tags$hr(),
    tagList(
      # "Schema URL (also local, for instance 'schema.json')",
      fluidRow(
        column(3, textInput("schema_url", label = NULL, value = schema_url, width = "100%")),
        column(2, 
               tagList(
                 tags$a(href = gsub("www/", "", schema_url), tagList(icon("arrow-right"), "Open schema"), target = "_blank"),
                 HTML("&nbsp;&nbsp;"),
                 actionLink("examples", tagList(icon("arrow-right"), "Examples"))),
               style = "text-align:left;padding-top:8px;"), 
        style="margin-bottom: -15px;")),
    tags$hr(),
    uiOutput("ui_description"),
    
    tags$hr(),

    sidebarLayout(
      # Sidebar with form input
      sidebarPanel(
            uiOutput("ui_inputs"),
            uiOutput("ui_add"),
        ),

      # Show a table of the data
      mainPanel(
        fileInput("upload", NULL, buttonLabel = "Modify a CSV...", multiple = FALSE, accept = c(".csv")),
        div(
          uiOutput("ui_text"),
          tags$br(),
          uiOutput("ui_edit_buttons"),
          tags$br(),
          dataTableOutput("ui_table"),
          uiOutput("ui_download"),
          style="padding:20px;border:1px solid #e3e3e3;border-radius:4px;")
      )
    ),
    tags$hr(),
    tagList("Created by Mathieu Rajerison (", tags$a(href="https://twitter.com/datagistips", "@datagistips", target="_blank"),") "),
    ", licensed under MIT Licence",
    tags$br(),
    tags$a(href="https://github.com/datagistips/shinyapps/tree/main/01_TableSchema", "View code on github", target="_blank")
)

# > SERVER ----
# Define server logic
server <- function(input, output, session) {
  
  # REACTIVE VALUES ----
  
  # JSON data
  r_j <- reactive({
    req(input$schema_url)
    j <- jsonlite::fromJSON(input$schema_url)
    return(j)
  })
  
  # Is schema valid ?
  r_valid <- reactive({
    schema_url <- input$schema_url
    
    valid_url <- function(url_in, t=2){
      con <- url(url_in)
      check <- suppressWarnings(try(open.connection(con,open="rt",timeout=t),silent=T)[1])
      suppressWarnings(try(close.connection(con),silent=T))
      ifelse(is.null(check),TRUE,FALSE)
    }
    
    if(grepl("^http", schema_url)) {
      return(valid_url(schema_url))
    } else {
      return(file.exists(schema_url))
    }
    
    return(valid)
  })
  
  # Get Id from schema
  r_id <- reactive({
    id <- default_id(input$schema_url)
    print(id)
    return(id)
  })
  
  # Get schema URL
  r_fields <- reactive({
    
    if(!r_valid()) return()
    fields <- get_fields(r_j())
    
    return(fields)
  })
  
  # Get schema description
  r_description <- reactive({
    return(get_description(r_j()))
  })
  
  # Get UIS
  r_uis <- reactive({
    if(is.null(r_fields())) return("Schema could not be read ! :-(")
    uis <- get_uis(r_fields(), 
                   id = r_id())
    return(uis)
  })
  
  # Store the row
  r_row <- reactive({
    # Select only form inputs (they start with 'ui__')
    input_names <- paste0("ui__", r_fields()$name)
    l <- lapply(input_names, function(x) input[[x]])
    # Convert the list to a data frame
    df <- data.frame(l)
    # Make beautiful data frame names
    names(df) <- gsub("ui__", "", input_names)
    
    return(df)
  })
  
  # This reactive Value will store the data frame  
  r_data <- reactiveValues(data = NULL)
  
  
  # OUTPUTS ----
  
  # # Foo
  # output$foo <- renderPrint({
  #   print(input$ui_table_cell_clicked$row)
  #   print(input$ui_table_cell_clicked$col)
  # })
  
  # Add button ?
  # "Add" button
  output$ui_add <- renderUI({
    if(r_valid()) {
      actionButton("add", "Add", icon = icon("plus"))
    } else {
      return()
    }
  })
  
  # Render description
  output$ui_description <- renderUI({
    r_description()
  })
  
  # Generate input panel
  output$ui_inputs <- renderUI({
    tagList(r_uis())
  })
  
  # Render data (which is in a reactive value)
  output$ui_table <- renderDT({
    datatable(r_data$data, editable = TRUE)
  })
  
  # Render edit buttons  
  output$ui_edit_buttons <- renderUI({
    if(!is.null(input$ui_table_rows_selected)) {
      s <- ifelse(length(input$ui_table_rows_selected) == 1, "row", "rows")
      res <- tagList(
        # actionButton("edit", "Edit"),
          actionButton("delete", glue("Delete {s}"), icon = icon("trash")),
          actionButton("copy", glue("Copy {s}"), icon = icon("copy")))
      } else {
        res <- ""
        if(!is.null(r_data$data)) {
          res <- tags$span("Click on a row to select it and remove or copy. Double-click on one or multiple rows to edit.", style="font-style:italic;")
        }
      }
    div(res, style = "height:30px;")
  })
  
  # Present the data (number of rows)
  output$ui_text <- renderUI({
    if(is.null(r_data$data)) {
      return("No rows for the moment...")
    } else {
      n <- nrow(r_data$data)
      s <- tagList(tags$strong(n), glue(" {ifelse(n == 1, 'row', 'rows')}"))
      return(s)
    }
  })
  
  # Download data handler
  output$download <- downloadHandler(
    filename = function() {
      "data.csv"
    },
    content = function(file) {
      write.csv(r_data$data, file, row.names = FALSE)
    }
  )
  
  # Download button or not download button
  output$ui_download <- renderUI({
    if(!is.null(r_data$data)) {
      tagList(
        tags$br(),
        downloadButton("download", "Download as CSV !", icon = icon("download")))
    }
  })
  
  
  # OBSERVERS -----
  
  # Examples
  observeEvent(input$examples, {
    examples <- c("https://raw.githubusercontent.com/etalab/tableschema-template/master/schema.json", "schema.json")
    examples <- lapply(examples, function(x) tags$p(x)) %>% tagList
    showModal(modalDialog(title = NULL, examples, footer = NULL, easyClose = T))
  })
  
  # Generate uuid
  observeEvent(input$uuid, {
    uuid <- UUIDgenerate()
    updateTextInput(session, "ui__id",
                      value = uuid)
  })
  
  # If you click on Add, it wil the row to the data
  observeEvent(input$add, {
    df <- r_data$data
    if(is.null(df)) {
      r_data$data <- r_row()
    } else {
      r_data$data <- rbind(df, r_row())
    }
  })
  
  # Delete rows
  observeEvent(input$delete, {
    w <- input$ui_table_rows_selected
    r_data$data <- r_data$data[-w, ]
  })
  
  # Copy rows
  observeEvent(input$copy, {
    # Get selected rows
    w <- input$ui_table_rows_selected
    rows <- r_data$data[w, ]
    print(rows)
    # Duplicate them
    r_data$data <- rbind(rows, r_data$data)
  })
  
  # Update the data frame if you edit the table
  observeEvent(input$ui_table_cell_edit, {
    i  <- input$ui_table_cell_edit$row
    j <- input$ui_table_cell_edit$col
    value <- input$ui_table_cell_edit$value
    r_data$data[i, j] <- value
  })
  
  # Upload
  observe({
    req(input$upload)
    datapath <- input$upload$datapath
    r_data$data <- read.csv(datapath)
  })
}

# Run the application !
shinyApp(ui = ui, server = server)