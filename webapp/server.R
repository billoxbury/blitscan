library(shiny)
library(dplyr)
library(stringr)
library(lubridate)

shinyServer(
  
  function(input, output, session) {
    # date range
    #start_date <- reactive({
    #  as_date(input$daterange[1])
    #})
    #end_date <- reactive({
    #  as_date(input$daterange[2])
    #})
    
    # show species:
    #updateSelectizeInput(session, 
    #                       "findspecies", 
#                           choices = SPECIES_LIST, 
  #                         server = TRUE)

    # set priority variable and traffic light points
    df_master <- rename(df_master, score = all_of(DEFAULT_PRIORITY))
    qs <- quantile(df_master$score, na.rm = TRUE)
    
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
    domainlogo <- function(domain){
      domainset <- c("nature.com",
                     "journals.plos.org",
                     "conbio.onlinelibrary.wiley.com",
                     "avianres.biomedcentral.com",
                     "ace-eco.org" ,
                     "cambridge.org",
                     "link.springer.com",
                     "mdpi.com",
                     "sciendo.com",
                     "int-res.com",
                     "orientalbirdclub.org",
                     "tandfonline.com",
                     "journals.sfu.ca",
                     "bioone.org/action/oai",
                     "bioone.org",
                     "asociacioncolombianadeornitologia.org",
                     "sciencedirect.com",
                     "academic.oup.com",
                     "biorxiv.org",
                     "nisc.co.za")
      logoset <- c("nature_logo.jpg",
                   "PLOS_logo.jpg",
                   "conbio.jpeg",
                   "avianres.png",
                   "ace-eco.png",
                   "cambridge.jpg",
                   "springer_link.jpg",
                   "mdpi.jpg",
                   "sciendo.jpg",
                   "int-res.jpg",
                   "orientalbirdclub.jpg",
                   "tandfonline.jpg",
                   "neotropica.jpg",
                   "bioone.jpg",
                   "bioone.jpg",
                   "colombiana.jpg",
                   "sciencedirect.jpg",
                   "oup.jpg",
                   "biorxiv.jpg",
                   "nisc.jpg")
      if(domain %in% domainset){
        icon <- logoset[which(domainset == domain)]
        # return
        sprintf("<img src='%s' width=100>", icon)
      } else {
        sprintf("<b>%s</b>", domain)
      }
    }
    
    # set the data frame - more efficient *not* to make this reactive,
    # but to filter only on smaller subframes
    df <- {
      df <- df_master 
      
      # set data frame names
      df <- rename(df, text = all_of(DEFAULT_TEXT_COLUMN))
      df$text[is.na(df$text)] <- ""
    
      df <- rename(df, bigtext = all_of(DEFAULT_HOVER_COLUMN))
      df$bigtext[is.na(df$bigtext)] <- ""
        
      df <- rename(df, link = all_of(DEFAULT_LINK_COLUMN))
      
      # set priority variable
      df <- rename(df, score = all_of(DEFAULT_PRIORITY))
      
      # don't restrict to date range just yet
      df <- rename(df, date = all_of(DEFAULT_DATE))
      
      # return
      df
    }
    
    recent <- {
      sapply(1:nrow(df_master), 
             function(i) (df$daysago[i] <= RECENT_DAYS) )
     }
    
    returned <- reactive({
      n <- nrow(df)
      f <- function(i){
          str_detect(str_to_lower(df$text[i]), 
                     str_to_lower(input$search)) |
            str_detect(str_to_lower(df$bigtext[i]), 
                       str_to_lower(input$search)) 
        }
      out <- if(input$search == ""){ 
        rep(FALSE, n) 
        } else {
        sapply(1:n, f)
        }
      #sp_out <- sapply(1:n, function(i){ 
      #    input$findspecies %in% extract_list(df$species[i])
      #    })

      # return
      #out | sp_out
      out
    })
    
    output$search_info <- renderText({
      #if(input$search == "" & input$findspecies == ""){ 
      if(input$search == ""){ 
          
        recent_date <- df$date[recent]
        recent_domain <- df$domain[recent]
        recent_text <- df$text[recent]
        recent_link <- df$link[recent]
        recent_score <- df$score[recent]
        recent_abstract <- df$bigtext[recent]
        
        s2 <- paste0("<tr><td width=100><font size=2.0>", recent_date, "</font></td>")
        s3 <- paste0("<td width=100>", sapply(recent_domain, domainlogo), "</td>")
        s4 <- paste0("<td width=800><a href='", recent_link, "'>", recent_text, "</td>")
        s5 <- paste0("<td>", sapply(recent_score, trafficlight), "</td></tr>")
        s6 <- paste0("<tr><td></td><td></td><td><p style='line-height:1.0'><font size=2.0>", recent_abstract, "</font></p></td><td></td></tr>")
        
        recent_out <- str_c(c("<table>", paste0(s2,s3,s4,s5,s6), "</table>"), collapse="")
         # return
        sprintf("<h3>Recent articles</h3> 
                %s",
                recent_out)
       } else {
          
        returned_date <- df$date[returned()]
        returned_domain <- df$domain[returned()]
        returned_text <- df$text[returned()]
        if(input$search != ""){
          returned_text <- returned_text %>% 
              str_replace_all(regex(input$search, ignore_case = TRUE), 
                              sprintf("<mark>%s</mark>", input$search))
        } 
        #if(input$findspecies != ""){
        #  returned_text <- returned_text %>% 
        #    str_replace_all(regex(input$findspecies, ignore_case = TRUE), 
        #                    sprintf("<mark>%s</mark>", input$findspecies))
        #} 
        returned_link <- df$link[returned()]
        returned_score <- df$score[returned()]
        returned_abstract <- df$bigtext[returned()] 
        if(input$search != ""){
          returned_abstract <- returned_abstract %>% 
            str_replace_all(regex(input$search, ignore_case = TRUE), 
                            sprintf("<mark>%s</mark>", input$search))
        } 
        #if(input$findspecies != ""){
        #  returned_abstract <- returned_abstract %>% 
        #    str_replace_all(regex(input$findspecies, ignore_case = TRUE), 
        #                    sprintf("<mark>%s</mark>", input$findspecies))
        #} 
        
        s2 <- paste0("<tr><td width=100><font size=2.0>", returned_date, "</font></td>")
        s3 <- paste0("<td width=100>", sapply(returned_domain, domainlogo), "</td>")
        s4 <- paste0("<td width=800><a href='", returned_link, "' target='_blank' rel='noopener noreferrer'>", returned_text, "</td>")
        s5 <- paste0("<td>", sapply(returned_score, trafficlight), "</td></tr>")
        s6 <- paste0("<tr><td></td><td></td><td><p style='line-height:1.0'><font size=2.0>", returned_abstract, "</font></p></td><td></td></tr>")
        
        return_out <- str_c(c("<table>", paste0(s2,s3,s4,s5,s6), "</table>"), collapse="")
        nresults <- sum(returned())
        # return
        if(nresults == 1){
          sprintf("<h3>Found 1 result</h3> 
                %s",
                  return_out)
          } else {
            sprintf("<h3>Found %d results</h3> 
                %s",
                    nresults, return_out)
                  }
        }
    })
    
    # DOESN'T WORK YET:
    #output$outtable <- DT::renderDataTable({

#        returned_date <- df()$date[returned()]
#        returned_domain <- df()$domain[returned()]
#        returned_text <- df()$text[returned()]
#        returned_link <- df()$link[returned()]
#        returned_score <- df()$score[returned()]
#        
#        domain_col <- sapply(returned_domain, domainlogo)
#        date_col <- returned_date
#        text_col <- if(length(returned_text) > 0){
#          sapply(1:length(returned_text), function(i){
#            sprintf("<a href='%s'>%s</a>", 
#                    returned_link[i],
#                    returned_text[i])
#            })
#          } else {
#            character(0)
#          }
#        score_col <- sapply(returned_score, trafficlight)
#        df_returned <- tibble(date_col,
#                              domain_col,
#                              text_col,
#                              score_col)
        # return
#        DT::datatable(df_returned, 
#                      rownames = FALSE,
#                      escape = FALSE,
#                      options = list(rowCallback = JS(
#                        "function(row, data) {",
#                        "var full_text = 'This row's values are :' + data[0] + ',' + data[1] + '...'",
#                        "$('td', row).attr('title', full_text);",
#                        "}"))
#    })
#        )
    
    output$sidebar <- renderText({
      sprintf("<h3>Getting started</h3>
      <p>This site contains scientific articles of relevance to the work of BirdLife International published in a number of open-access journals.</p>
      <p>The database is updated regularly and currently contains <b>%d articles</b>.</p>
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
              <hr>",
              nrow(df_master))
    })
   }
)

