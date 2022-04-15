library(shiny)
library(shinyjs)
library(shinyWidgets)

source("setup.R")

shinyUI(fluidPage(
  
  # suppresses spurious 
  # 'progress' error messages after all the debugging 
  # is done:
  tags$style(type="text/css",
             ".shiny-output-error { visibility: hidden; }",
             ".shiny-output-error:before { visibility: hidden; }"
  ),
  HTML("<style>
         table {
           border-collapse: separate;
           border-spacing: 0 10px;
         }
       th {
         background-color: #4287f5;
           color: white;
       }
       th,
       td {
         font-size: 16px;
         text-align: left;
         padding: 5px;
       }
       h1 {
        font-size: 44px;
         color: #4287f5;
       }
       h2 {
         color: #4287f5;
       }
       h3 {
         color: #4287f5;
       }
       b {
         color: #4287f5;
       }
       </style>"),

 # HTML('<table width="100%">
 #<tr>
#  <td width="20%"><img src="ace-eco.png" height = 35></td>
#  <td width="20%"><img src="avianres.png" height = 40></td>
#  <td width="20%"><img src="conbio.jpeg"" height = 50></td>
#  <td width="20%"><img src="PLOS_logo.jpg" height = 50></td>
#  <td width="20%"><img src="nature_logo.jpg" height = 45></td>
# </tr>
#<table>'),
#  HTML("<hr>"),
  HTML("<h1 id='logo'><a href='https://www.birdlife.org/'><img src='birdlifeinternational.jpg' alt='logo' width=160></a> LitScan</h1>"),
  HTML("<i>&#945 version</i><hr>"),
  
  sidebarLayout(
    position="left",
    fluid = TRUE,
    
    mainPanel( 
      fluidRow(
        column(4,
               textInput("search", 
                         label = "Search", 
                         value = "")
        ),        
        column(3,
               selectizeInput(
                "findspecies",
                 label = "Species present",
                 choices = NULL)
        ),
        column(4,
               dateRangeInput("daterange", "Date range",
                              start = START_DATE,
                              end   = END_DATE)
        )
      ),
     HTML("<hr>"),
     htmlOutput("search_info"),
     HTML("<hr>
          <a href='mailto: oxburybill@gmail.com'>&#169; Bill Oxbury 2022</a>")
     #textOutput("outtable") # DEBUGGING
     #dataTableOutput("outtable") # <--- NOT COMPATIBLE WITH TEXT ENTRIES?
    ),
    sidebarPanel(
      htmlOutput("sidebar")
    )
    )
  )
)

