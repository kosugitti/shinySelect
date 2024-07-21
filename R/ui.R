shinyUI(
  navbarPage("一般分類機",
             tabPanel("ファイル読み込み",
                      sidebarLayout(
                        sidebarPanel(
                          # ファイルを選択するための入力
                          fileInput("file", "ファイルを選択", accept = c(".xlsx", ".csv")),
                          
                          # 使用する列番号を指定するための数値入力
                          numericInput("column_index", "使用する列番号", value = 1, min = 1),
                          
                          # 一行目をデータとして読み込むチェックボックス
                          checkboxInput("header", "一行目に変数名", value = TRUE),
                          
                          # 読み込みボタン
                          actionButton("load_data", "データを読み込む"),
                          
                          # エラーメッセージを表示するためのテキスト
                          textOutput("error_message")
                        ),
                        mainPanel(
                          # データのプレビューと確認ボタンを表示
                          tableOutput("data_preview"),
                          conditionalPanel(
                            condition = "output.data_loaded",
                            actionButton("confirm_data", "確認")
                          )
                        )
                      )
             ),
             tabPanel("分類",
                      sidebarLayout(
                        sidebarPanel(
                          # 出力ファイル名を入力するためのテキスト入力
                          textInput("output_filename", "出力ファイル名", value = "classified_data.csv"),
                          
                          hr(),
                          
                          # 新しいカテゴリ名を入力するためのテキスト入力
                          textInput("category_name", "カテゴリ名"),
                          
                          # 新しいカテゴリを作成するためのボタン
                          actionButton("create_category", "新しいカテゴリを作る"),
                          br(),
                          
                          hr(),
                          
                          # 編集するカテゴリを選択するためのドロップダウン
                          selectInput("category_to_edit", "編集するカテゴリを選択", choices = NULL),
                          
                          # 新しいカテゴリ名を入力するためのテキスト入力
                          textInput("new_category_name", "新しいカテゴリ名"),
                          
                          # カテゴリ名を変更するためのボタン
                          actionButton("edit_category", "カテゴリ名を変更"),
                          br(),
                          
                          hr(),
                          
                          # 進捗状況を表示するためのテキスト
                          textOutput("progress_text"),
                          
                          # プログレスバーを追加
                          progressBar(id = "progress_bar", value = 0),
                          
                          # 前に戻るボタンを追加
                          actionButton("prev_button", "Prev"),
                          
                          # 次の文章に行くボタンを追加
                          actionButton("next_button", "Next")
                        ),
                        mainPanel(
                          br(),
                          # 現在の文章を表示するためのテキスト
                          h3(textOutput("sentence"), style = "text-align: center; font-size: 20px;"),
                          br(),
                          
                          # カテゴリを表示するためのセクション
                          h4("カテゴリ"),
                          uiOutput("categories"),
                          br(),
                          
                          # 現在のカテゴリを表示するためのテキスト
                          h4(textOutput("current_category"), style = "text-align: center; color: green;"),
                          br(),
                          
                          # 休憩メッセージを表示するためのテキスト
                          h3(textOutput("rest_message"), style = "text-align: center; font-size: 24px; color: red;"),
                          
                          # 感謝メッセージを表示するためのテキスト
                          h3(textOutput("thanks_message"), style = "text-align: center; font-size: 24px; color: blue;")
                        )
                      )
             )
  )
)
