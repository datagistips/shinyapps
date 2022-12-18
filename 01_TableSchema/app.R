library(shiny)
library(jsonlite)
library(tidyverse)
library(DT)
library(glue)

# Read TableSchema
schema_url <- "https://raw.githubusercontent.com/etalab/tableschema-template/master/schema.json"
j <- jsonlite::fromJSON(schema_url)

# > FUNCTIONS ----
get_fields <- function(j) {
  fields <- j$fields
  fields
}

get_ui <- function(field) {
  # Gets the UI for a specific field
  
  name <- field$name
  example <- field$example
  description <- field$description
  constraints <- field$constraints
  
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
                helpText(description)) # We add the description as a help text to fill the information
  
  return(ui)
}

get_uis <- function(fields) {
  # Gets the UI elements
  
  uis <- vector(mode = "list")
  # List all fields and calculate the UI element
  for(i in 1:nrow(fields)) {
    field <- fields[i, ]
    ui <- get_ui(field)
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
  
  tagList(tags$p("Name : ", name), 
          tags$p("Title : ", title),
          tags$p("Description : ", description),
          tags$p("Authors : ", contributors))
}

# NOW is the app !

# > UI ----
ui <- fluidPage(
    
    # Title panel
    titlePanel("TableSchema example"),
    
    # Some description
    tags$p(tags$i("This apps reads a ", tags$a(href="https://specs.frictionlessdata.io/table-schema/", "TableSchema"), " and generates a form depending on the fields listed in the schema")),
    tags$p("This is an adaptation of Etalab", tags$a(href="https://github.com/etalab/csv-gg", "CSV-GG")),
    uiOutput("ui_description"),
    tagList(
      "Schema URL",
      textInput("schema_url", label = NULL, value = schema_url, width = "50%"),
      "↑ It can also be local, for instance 'mypath/schema.json'"),
    tags$hr(),

    sidebarLayout(
      # Sidebar with form input
      sidebarPanel(
            uiOutput("ui_inputs"),
            actionButton("add", "Add", icon = icon("plus"))
        ),

      # Show a table of the data
      mainPanel(
        fileInput("upload", NULL, buttonLabel = "Modify a CSV...", multiple = FALSE, accept = c(".csv")),
        uiOutput("ui_text"),
        tags$br(),
        uiOutput("ui_edit_buttons"),
        tags$br(),
        dataTableOutput("ui_table"),
        uiOutput("ui_download")
      )
    )
)

# > SERVER ----
# Define server logic
server <- function(input, output) {
  
  # REACTIVE VALUES ----
  
  # Get schema URL
  r_fields <- reactive({
    schema_url <- input$schema_url
    j <- jsonlite::fromJSON(schema_url)
    fields <- get_fields(j)
    return(fields)
  })
  
  # Get schema description
  r_description <- reactive({
    return(get_description(j))
  })
  
  # Get UIS
  r_uis <- reactive({
    return(get_uis(r_fields()))
  })
  # Store the row
  r_row <- reactive({
    # Select only form inputs (they start with 'ui__')
    w <- grep("^ui__", names(input))
    input_names <- names(input)[w]
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
      tagList(
        # actionButton("edit", "Edit"),
        actionButton("delete", glue("Delete {s}"), icon = icon("trash")),
        actionButton("copy", glue("Copy {s}"), icon = icon("copy"))
        )
    }
  })
  
  # Present the data (number of rows)
  output$ui_text <- renderUI({
    if(is.null(r_data$data)) {
      return("No rows for the moment...")
    } else {
      s <- tagList(tags$strong(nrow(r_data$data)), " rows (you can edit the table by double-clicking on the cell)")
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