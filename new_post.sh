#!/bin/bash
# Script: new-post.sh - Tạo bài viết CTF mới cho blog Jekyll (GitHub Pages)

# Kiểm tra tham số đầu vào
if [ $# -lt 2 ]; then
  echo "Sử dụng: $0 <tên-chuyên-mục> <tiêu đề bài viết>"
  echo "Ví dụ: $0 HTB \"Kenobi\""
  exit 1
fi

# Lấy tham số chuyên mục và tiêu đề
category_original="$1"       # Tên chuyên mục như người dùng nhập (có thể có dấu, khoảng trắng)
shift
title_original="$*"          # Tiêu đề bài viết (cho phép nhiều từ không cần tự nối chuỗi bằng dấu \" \")

# Xử lý an toàn tên chuyên mục (loại bỏ dấu, ký tự đặc biệt, khoảng trắng)
if ! command -v iconv >/dev/null 2>&1; then
  echo "Lỗi: Không tìm thấy lệnh 'iconv'. Vui lòng cài đặt iconv để xử lý ký tự Unicode."
  exit 1
fi
# Loại bỏ dấu tiếng Việt và ký tự Unicode (chuyển về ASCII gần tương đương)
category_safe=$(echo "$category_original" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null)
# Thay khoảng trắng và ký tự đặc biệt bằng dấu gạch dưới, bỏ ký tự không hợp lệ
category_safe=$(echo "$category_safe" | sed -r 's/[^A-Za-z0-9]+/_/g')
# Bỏ gạch dưới thừa ở đầu/cuối chuỗi (nếu có)
category_safe=$(echo "$category_safe" | sed -r 's/^_+|_+$//g')

# Xử lý an toàn tiêu đề bài viết (tạo slug không dấu, viết thường, dùng '-' nối từ)
title_slug=$(echo "$title_original" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null)
title_slug=$(echo "$title_slug" | sed -r 's/[^A-Za-z0-9]+/-/g')
title_slug=$(echo "$title_slug" | sed -r 's/^-+|-+$//g')        # bỏ '-' thừa đầu/cuối
title_slug=$(echo "$title_slug" | tr 'A-Z' 'a-z')               # chuyển thành chữ thường

# Đặt đường dẫn thư mục collection và file bài viết
collection_dir="_${category_safe}"
today=$(date +%Y-%m-%d)
post_filename="${today}-${title_slug}.md"
post_filepath="${collection_dir}/${post_filename}"
collection_page="${category_safe}.html"  # trang HTML liệt kê bài trong chuyên mục

# Kiểm tra thư mục gốc Jekyll
if [ ! -f "_config.yml" ]; then
  echo "Lỗi: Không tìm thấy _config.yml. Hãy chạy script tại thư mục gốc của blog Jekyll."
  exit 1
fi

# Tạo thư mục collection nếu chưa tồn tại
if [ ! -d "$collection_dir" ]; then
  mkdir "$collection_dir"
  echo "Đã tạo thư mục mới: $collection_dir/"
else
  echo "Thư mục $collection_dir/ đã tồn tại."
fi

# Cập nhật cấu hình _config.yml cho collection mới
collection_key="$category_safe"
collection_exists=false
if grep -qE "^ {0,}$collection_key:" "_config.yml"; then
  # Đã có khóa collection này trong cấu hình
  collection_exists=true
fi

if grep -qE "^collections:" "_config.yml"; then
  # Đã có phần collections trong config
  if [ "$collection_exists" = false ]; then
    # Thêm cấu hình cho collection mới dưới khóa collections
    # Thêm dòng vào sau dòng 'collections:' hoặc sau các collection khác
    # Tìm dòng bắt đầu bằng 'collections:' và chèn sau đó (giữ thụt lề 2 khoảng)
    sed -i "/^collections:/a\\
  $collection_key:\\
    output: true\\
    permalink: /$collection_key/:title/
    " _config.yml
    echo "Đã thêm cấu hình cho collection '$collection_key' vào _config.yml."
  else
    echo "Collection '$collection_key' đã được khai báo trong _config.yml, bỏ qua bước thêm cấu hình."
  fi
else
  # Chưa có mục collections: -> thêm mới hoàn toàn
  cat >> "_config.yml" <<END

collections:
  $collection_key:
    output: true
    permalink: /$collection_key/:title/
END
  echo "Đã tạo mục collections và thêm collection '$collection_key' vào _config.yml."
fi

# Tạo file markdown cho bài viết mới
if [ -f "$post_filepath" ]; then
  echo "Lưu ý: File bài viết $post_filepath đã tồn tại, bỏ qua bước tạo file."
else
  # Nội dung front matter cho bài viết mới
  # (Chú ý thoát ký tự đặc biệt trong tiêu đề)
  safe_title_yaml=$(echo "$title_original" | sed 's/\\/\\\\/g; s/\"/\\"/g')
  cat > "$post_filepath" <<END
---
layout: post
title: "$safe_title_yaml"
date: $(date +%Y-%m-%d\ %H:%M:%S\ %z)
tags: [CTF]
---
<!-- Viết nội dung write-up tại đây -->
END
  echo "Đã tạo bài viết mẫu: $post_filepath"
fi

# Tạo trang HTML liệt kê bài viết của collection (nếu chưa có)
if [ ! -f "$collection_page" ]; then
  echo "Tạo trang danh mục: $collection_page"
  echo "---" > "$collection_page"
  echo "layout: default" >> "$collection_page"
  echo "title: \"$category_original\"" >> "$collection_page"
  echo "---" >> "$collection_page"
  echo "<h1>Danh sách bài viết - $category_original</h1>" >> "$collection_page"
  echo "<ul>" >> "$collection_page"
  # Vòng lặp liệt kê các bài viết trong collection
  echo "{% for post in site.$collection_key %}" >> "$collection_page"
  echo "  <li><a href=\"{{ post.url }}\">{{ post.title }}</a> – {{ post.date | date: \"%Y-%m-%d\" }}</li>" >> "$collection_page"
  echo "{% endfor %}" >> "$collection_page"
  echo "</ul>" >> "$collection_page"
else
  echo "Trang $collection_page đã tồn tại, bỏ qua bước tạo."
fi

# Thêm liên kết chuyên mục vào menu (index.html hoặc nav.html)
menu_file=""
if [ -f "_includes/nav.html" ]; then
  menu_file="_includes/nav.html"
elif [ -f "index.html" ]; then
  menu_file="index.html"
fi

if [ -n "$menu_file" ]; then
  # Kiểm tra nếu liên kết đã có
  if grep -q "$collection_page" "$menu_file"; then
    echo "Menu đã có mục $category_original, bỏ qua bước cập nhật menu."
  else
    echo "Đang cập nhật menu trong $menu_file ..."
    # Chèn link vào menu (trước thẻ đóng </ul> nếu có)
    if grep -q "</ul>" "$menu_file"; then
      sed -i "/<\/ul>/ i\\
<li><a href=\"$collection_page\">$category_original</a></li>" "$menu_file"
    else
      # Nếu không có <ul>, thì thêm dạng dòng mới
      echo "<a href=\"$collection_page\">$category_original</a><br>" >> "$menu_file"
    fi
    echo "Đã thêm liên kết chuyên mục '$category_original' vào $menu_file."
  fi
else
  echo "Không tìm thấy file menu (nav.html hoặc index.html) để cập nhật liên kết chuyên mục."
fi

echo "Hoàn tất! Hãy mở $post_filepath để viết nội dung, sau đó chạy \`jekyll serve\` để kiểm tra."
