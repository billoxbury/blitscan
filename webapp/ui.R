source("setup.R")

# setwd("~/Projects/202201_BI_literature_scanning/webappSQL/webapp")

shinyUI(fluidPage(
  
  # login section
  shinyauthr::loginUI(id = "login"),
  
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

  sidebarLayout(
    position="left",
    fluid = TRUE,
    mainPanel( 
        htmlOutput("header"), # title bar
        uiOutput("search"),
        htmlOutput("search_info"), # search results
        htmlOutput("signoff"), # footer
      ),
      sidebarPanel( 
        logoutUI(id = "logout"), # logout button
        htmlOutput("sidebar")
      )
    )
  )
)

