library(shiny)
library(shinyWidgets)
library(readxl)
library(dplyr)
library(openxlsx)

shinyServer(function(input, output, session) {
  # リアクティブ値の初期化
  sentences <- reactiveVal(NULL)
  current_sentence_index <- reactiveVal(1)
  categories <- reactiveVal(list())
  category_counts <- reactiveVal(list())
  selected_category <- reactiveVal(NULL)
  df <- reactiveVal(NULL)
  error_message <- reactiveVal("")
  category_counter <- reactiveVal(1)
  total_sentences <- reactiveVal(0)
  classified_sentences <- reactiveVal(0)
  loaded_data <- reactiveVal(NULL)
  
  # データがロードされたかを示すフラグ
  data_loaded <- reactiveVal(FALSE)
  
  # データプレビューの出力
  output$data_preview <- renderTable({
    head(loaded_data())
  })
  
  # データがロードされたかどうかを示す
  output$data_loaded <- reactive({
    data_loaded()
  })
  outputOptions(output, "data_loaded", suspendWhenHidden = FALSE)
  
  # ファイル読み込みボタンの処理
  observeEvent(input$load_data, {
    req(input$file)
    file <- input$file$datapath
    file_ext <- tools::file_ext(file)
    
    # ファイルの拡張子に応じて読み込み
    if (file_ext == "xlsx") {
      data <- read_excel(file, col_names = input$header)
    } else if (file_ext == "csv") {
      data <- read.csv(file, header = input$header)
    } else {
      error_message("Unsupported file type")
      return()
    }
    
    # 使用する列番号を取得
    column_index <- input$column_index
    
    # 指定された列を使用してデータを抽出
    if (column_index <= ncol(data)) {
      target_sentences <- unlist(data[[column_index]])
    } else {
      error_message("Invalid column index")
      data_loaded(FALSE)
      return()
    }
    
    # Button_IDとButton_Labelの列が存在しない場合は追加
    if (!"Button_ID" %in% names(data)) {
      data$Button_ID <- NA
    } else {
      data$Button_ID <- as.numeric(gsub("category_", "", data$Button_ID))
    }
    if (!"Button_Label" %in% names(data)) {
      data$Button_Label <- NA
    }
    
    # 必要な列のみを抽出
    processed_data <- data.frame(
      Target_Sentences = target_sentences,
      Button_ID = data$Button_ID,
      Button_Label = data$Button_Label,
      stringsAsFactors = FALSE
    )
    
    processed_data <- processed_data %>%
      arrange(is.na(Button_ID), Button_ID)
    
    loaded_data(processed_data)  # プレビュー用にデータを保存
    data_loaded(TRUE)  # データがロードされたことを示す
  })
  
  # 確認ボタンの処理
  observeEvent(input$confirm_data, {
    data <- loaded_data()
    sentences(data$Target_Sentences)
    total_sentences(length(sentences()))
    
    # Button_IDとButton_Labelを文字型に変換
    data$Button_ID[is.na(data$Button_ID)] <- ""
    data$Button_Label[is.na(data$Button_Label)] <- ""
    df(data)  # データフレームをリアクティブ値に保存
    
    # 次の未分類の文章を見つける
    if (length(sentences()) > 0) {
      current_sentence_index(find_next_unclassified_sentence(data))
    } else {
      current_sentence_index(NULL)
    }
    
    # 既存のカテゴリとカウントの初期化
    existing_categories <- unique(data$Button_Label[data$Button_Label != ""])
    categories(existing_categories)
    counts <- as.list(setNames(rep(0, length(existing_categories)), existing_categories))
    category_counts(counts)
    
    # 次のカテゴリIDを決定
    if (any(data$Button_ID != "")) {
      max_category_number <- max(as.numeric(data$Button_ID), na.rm = TRUE)
      category_counter(max_category_number + 1)
    } else {
      category_counter(1)
    }
    
    # 分類された文章をカウント
    classified_sentences(sum(data$Button_ID != ""))
    update_category_choices() # UIのカテゴリ選択肢を更新
    
    # 分類タブに移動
    updateNavbarPage(session, "一般分類機", selected = "分類")
  })
  
  # 次の未分類の文章を見つける関数
  find_next_unclassified_sentence <- function(data) {
    for (i in 1:nrow(data)) {
      if (data$Button_ID[i] == "") {
        return(i)
      }
    }
    return(nrow(data) + 1)
  }
  
  # 新しいカテゴリを作成
  observeEvent(input$create_category, {
    req(input$category_name)
    categories_list <- categories()
    category_name <- input$category_name
    counts <- category_counts()
    
    # 新しいカテゴリが存在しない場合に追加
    if (!category_name %in% categories_list) {
      categories_list <- c(categories_list, category_name)
      categories(categories_list)
      counts[[category_name]] <- 0
      category_counts(counts)
      category_counter(category_counter() + 1)
      update_category_choices()
    }
  })
  
  # UIのカテゴリ選択肢を更新する関数
  update_category_choices <- function() {
    categories_list <- categories()
    updateSelectInput(session, "category_to_edit", choices = categories_list)
  }
  
  # 既存のカテゴリを編集
  observeEvent(input$edit_category, {
    req(input$new_category_name, input$category_to_edit)
    categories_list <- categories()
    counts <- category_counts()
    
    old_name <- input$category_to_edit
    new_name <- input$new_category_name
    
    # 新しい名前が既存のカテゴリにない場合に変更
    if (new_name %in% categories_list) {
      error_message("The new category name already exists.")
    } else {
      categories_list[categories_list == old_name] <- new_name
      categories(categories_list)
      
      counts[[new_name]] <- counts[[old_name]]
      counts[[old_name]] <- NULL
      category_counts(counts)
      update_category_choices()
    }
  })
  
  # カテゴリごとに動的にボタンを生成
  observe({
    categories_list <- categories()
    output$categories <- renderUI({
      lapply(seq_along(categories_list), function(i) {
        actionButton(paste0("category_", i), categories_list[[i]])
      })
    })
  })
  
  # 選択されたカテゴリを表示
  output$current_category <- renderText({
    selected_category()
  })
  
  # 現在の文章を表示
  output$sentence <- renderText({
    req(sentences())
    sentences()[current_sentence_index()]
  })
  
  # 分類の進捗状況を表示
  output$progress_text <- renderText({
    paste(classified_sentences(), "out of", total_sentences(), "sentences classified")
  })
  
  # 次の文章へ移動
  observeEvent(input$next_button, {
    req(current_sentence_index() < total_sentences())
    current_sentence_index(current_sentence_index() + 1)
  })
  
  # 前の文章へ移動
  observeEvent(input$prev_button, {
    req(current_sentence_index() > 1)
    current_sentence_index(current_sentence_index() - 1)
  })
  
  # カテゴリボタンクリックを処理し、分類カウントを更新
  observe({
    categories_list <- categories()
    for (i in seq_along(categories_list)) {
      local({
        category_id <- i
        category_name <- categories_list[[i]]
        observeEvent(input[[paste0("category_", category_id)]], {
          counts <- category_counts()
          counts[[category_name]] <- counts[[category_name]] + 1
          category_counts(counts)
          saveExistingCategory(category_id, category_name)
        })
      })
    }
  })
  
  # データを保存する関数
  save_dataframe <- function(data) {
    output_filename <- input$output_filename
    write.csv(data, output_filename, row.names = FALSE)
  }
  
  saveExistingCategory <- function(category_id, category_name) {
    current_sentence_index_val <- current_sentence_index()
    if (!is.null(sentences()) && !is.null(current_sentence_index_val) && current_sentence_index_val <= length(sentences())) {
      print(paste("文章:", sentences()[current_sentence_index_val], "を既存のカテゴリ:", category_name, "に関連付けました。"))
      
      new_data <- df()
      new_data <- new_data %>%
        mutate(
          Button_ID = ifelse(row_number() == current_sentence_index_val, as.character(category_id), Button_ID),
          Button_Label = ifelse(row_number() == current_sentence_index_val, category_name, Button_Label)
        )
      
      save_dataframe(new_data)
      
      df(new_data)
      classified_sentences(sum(df()$Button_ID != ""))
    }
  }
})
