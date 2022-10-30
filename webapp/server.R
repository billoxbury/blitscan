shinyServer(
  
  function(input, output, session) {
    
    # set traffic light points
    score <- df_tx %>%
      pull(score)
    qs <- quantile(score, na.rm = TRUE)
    
    # divide score into quantiles with boundaries at
    # 0% 25% 50% 75% 100%
    # we'll set
    # RED below 50%
    # AMBER below 75%
    # GREEN above 75%
    trafficlight <- function(score){
      icon <- if(score < qs[3]){ 
        "redlight.png" } else 
          if(score < qs[4]){
            "amberlight.png"
          } else {
            "greenlight.png"
          }
      # return
      sprintf("<img src='%s' width=25>", icon)
    }
    
    # pull data frame of recent items
    # (not reactive, but could be made reactive to user-selected date range)
    df_recent <- df_tx %>%
      filter(!is.na(date)) %>%
      mutate(date = as_date(date)) %>%
      filter(as.integer(today() - date) <= RECENT_DAYS) %>%
      select(date, title, abstract, score, link, domain, doi) %>%
      arrange(desc(score)) %>%
      collect()
    
    # decouple query term from live text input
    query <- reactive({
      #if(str_detect(input$search, '\n')){
      #  str_remove(input$search, '\n')
      #} else {
      #  ''
      #}
      input$search
    })
    
    # pull data frame in response to search term
    df_returned <- reactive({
      if(query() == ""){
        df_recent
      } else {
        st <- query() %>% tolower()
        df_out <- if(input$pdfsearch) { df_tx %>%
            filter(str_detect(tolower(pdftext), st) |
                     str_detect(tolower(pdftext_translation), st)) 
        } else {
          df_tx %>%
            filter(str_detect(tolower(title), st) |
                     str_detect(tolower(title_translation), st) |
                     str_detect(tolower(abstract), st) |
                     str_detect(tolower(abstract_translation), st)) 
        }
        # return
        df_out %>%
          select(date, title, abstract, score, link, domain, doi) %>%
          arrange(desc(score)) %>%
          collect() 
      }
    })
    
    output$header <- renderText({
      "<h1 id='logo'><a href='https://www.birdlife.org/'><img src='birdlifeinternational.jpg' alt='logo' width=160></a> LitScan</h1>
      <i>&#946 version</i><hr>"
    })
    
    output$search <- renderUI({
      tagList(
        searchInput(label = "Search", 
                    inputId = "search", 
                    placeholder = "",
                    #btnSearch = icon("magnifying-glass"),
                    width = "500px"
        ),
        checkboxInput("pdfsearch",
                      label = "Search full PDF text", 
                      value = FALSE)
      )
    })
    
    output$search_info <- renderText({
      # returned data frame
      df_out <- df_returned()
      nresults <- nrow(df_out)
      
      # components to display
      date <- df_out$date
      #doi <- df_out$doi
      domain <- df_out$domain
      title <- df_out$title
      link <- df_out$link
      score <- df_out$score
      abstract <- df_out$abstract %>% 
        str_replace_all("<\\/?[a-z][0-9]?>", " ") 
      #publisher <- sapply(1:nresults, function(i){
      #  if(domain[i] == 'doi.org') find_publisher(doi[i])
      #  else domain[i]
      #})

      # mark up search terms
      if(query() != ""){
        title <- title %>% 
          str_replace_all(regex(query(), ignore_case = TRUE), 
                          sprintf("<mark>%s</mark>", input$search))
        abstract <- abstract %>% 
          str_replace_all(regex(query(), ignore_case = TRUE), 
                          sprintf("<mark>%s</mark>", input$search))
      } 
      
      # create output HTML
      s2 <- paste0("<tr><td width=100><font size=2.0>", date, "</font></td>")
      s3 <- paste0("<td width=100>", sapply(domain, domainlogo), "</td>")
      s4 <- paste0("<td width=800><a href='", link, "'>", title, "</td>")
      s5 <- paste0("<td>", sapply(score, trafficlight), "</td></tr>")
      s6 <- paste0("<tr><td></td><td></td><td><p style='line-height:1.0'><font size=2.0>", abstract, "</font></p></td><td></td></tr>")
        
      text_out <- str_c(c("<table>", paste0(s2,s3,s4,s5,s6), "</table>"), collapse="")
      
      # return
      if(query() == ""){
        sprintf("<h3>Recent articles</h3> 
                %s",
                text_out)
      } else {
        if(nresults == 1){
          sprintf("<h3>Found 1 result</h3> 
                %s",
                  text_out)
        } else {
          sprintf("<h3>Found %d results</h3> 
                %s",
                  nresults, text_out)
        }
      }
     })
    
    output$signoff <- renderText({
      "<hr>
       <a href='mailto: bill.oxbury@birdlife.org'>&#169; BirdLife International 2022</a>"
    })

    output$sidebar <- renderText({
      sprintf("
      <br>
      <hr>
      <h3>Getting started</h3>
      <p>
      This site identifies scientific articles of relevance to Red List assessments for birds undertaken by BirdLife International. It covers articles published in a number of primarily open-access journals.
      </p>
      <p>
      The database is updated regularly and currently contains <b>%s articles</b> published in the <b color='red'>past 6 years</b>.
              </p>
              <p>
              The relevance of articles for Red List assessments is estimated based on text analysis using the existing assessments.
              The estimate is indicated on this page by a traffic light 
              <img src='redlight.png' width=20><img src='amberlight.png' width=20><img src='greenlight.png' width=20>.
              </p>
              <p>
              The relevance algorithm is under development and doesn't always get it right (yet)! <b>User feedback is welcome</b> to help improve it and to speedily highlight valuable research.
              </p>
              <p>Recent articles should appear here daily.</p> 
              <p>Search <b>by keyword/phrase</b> (followed by return).</p>
              <p>
              <a href='%s'>More information can be found here.</a>
              </p>
              <hr>
              ", 
              format(nrows, big.mark=','),
              sprintf("scraper_dashboard.html")
      )
    })
   }
)
