options(warn=-1)

rsconnect::setAccountInfo(name='datagistips',
                          token='07B1C6171E149F0CD44164C647A80072',
                          secret='<SECRET>')

# Deploy tableschema app
rsconnect::deployApp(appName = "tableschema", 
                     appDir = "../01_TableSchema/", 
                     account="datagistips", 
                     forceUpdate = T, launch.browser = launch_browser)