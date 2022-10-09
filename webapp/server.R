library(stringr)

shinyServer(
  
  function(input, output, session) {
    
    if(!LOCAL){
      credentials <- shinyauthr::loginServer(
        id = "login",
        data = user_base,
        user_col = user,
        pwd_col = password,
        sodium_hashed = TRUE,
        log_out = reactive(logout_init())
      )
      
      # logout to hide
      logout_init <- shinyauthr::logoutServer(
        id = "logout",
        active = reactive(credentials()$user_auth)
      )
    }

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
      collect() %>%
      mutate(date = as_date(date), query_date = as_date(query_date)) %>%
      filter(as.integer(today() - date) <= RECENT_DAYS) %>%
      arrange(desc(score))
    
    # pull data frame in response to search term
    dftx_text_query <- function(st){
      search <- sprintf("%%%s%%", st)
      # return
      sprintf("SELECT * FROM links \
                          WHERE GOTTEXT=1 AND BADLINK=0 AND score > -20.0 \
                          AND (title LIKE '%s' OR abstract LIKE '%s' \
                          OR title_translation LIKE '%s' OR abstract_translation LIKE '%s')", 
              search, search, search, search)
    }
    df_returned <- reactive({
      sql_query <- dftx_text_query(input$search)
      # return
      tbl(conn, sql(sql_query)) %>%
        collect() %>%
        mutate(date = as_date(date), query_date = as_date(query_date)) %>%
        arrange(desc(score))
    })

    output$header <- renderText({
      # show only when authenticated
      if(!LOCAL) req(credentials()$user_auth)
      "<h1 id='logo'><a href='https://www.birdlife.org/'><img src='birdlifeinternational.jpg' alt='logo' width=160></a> LitScan</h1>
      <i>&#946 version</i><hr>"
    })
    
    output$search <- renderUI({
      # show only when authenticated
      if(!LOCAL) req(credentials()$user_auth)
      
      tagList(
        textInput("search", 
                  label = "Search", 
                  value = "")
      )
    })
    
    output$search_info <- renderText({
      # show only when authenticated
      if(!LOCAL) req(credentials()$user_auth)
      
      # returned data frame
      df_out <- if(input$search == ""){ 
          df_recent 
        } else { 
          df_returned()
        }
      nresults <- nrow(df_out)
      
      # components to display
      date <- df_out$date
      domain <- df_out$domain
      title <- df_out$title
      link <- df_out$link
      score <- df_out$score
      abstract <- df_out$abstract
        
      # mark up search terms
      if(input$search != ""){
        title <- title %>% 
          str_replace_all(regex(input$search, ignore_case = TRUE), 
                          sprintf("<mark>%s</mark>", input$search))
        abstract <- abstract %>% 
          str_replace_all(regex(input$search, ignore_case = TRUE), 
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
      if(input$search == ""){
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
      # show only when authenticated
      if(!LOCAL) req(credentials()$user_auth)
      
      "<hr>
       <a href='mailto: bill.oxbury@birdlife.org'>&#169; BirdLife International 2022</a>"
    })

    output$sidebar <- renderText({
      # show only when authenticated
      if(!LOCAL) req(credentials()$user_auth)
      
      sprintf("
      <br>
      <hr>
      <h3>Getting started</h3>
      <p>This site contains scientific articles of relevance to the work of BirdLife International published in a number of open-access journals.</p>
      <p>The database is updated regularly and currently contains <b>%s articles</b>.</p>
              <p>All articles for which the date is available are published within the <b color='red'>past 6 years</b>.</p>
              <p>The relevance of articles to conservation is estimated based on text analysis using the red-list species assessments of Birdlife International.</p>
              <p>The estimate is indicated on this page by a traffic light 
              <img src='redlight.png' width=20><img src='amberlight.png' width=20><img src='greenlight.png' width=20>.</p>
              <p>The relevance algorithm is under development and doesn't always get it right (yet)! <b>User feedback is welcome</b> to help improve it and to speedily highlight valuable research.</p>
              <p>Recent articles should appear here daily.</p> 
              <p>Search <b>by keyword/phrase</b>.</p>
              <p>
              <a href='scraper_dashboard.html'>More information can be found here.</a>
              </p>
              <hr>
              ", format(nrows, big.mark=','))
    })
   }
)
