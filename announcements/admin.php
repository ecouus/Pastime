<?php
// 初始化变量
$message = '';
$error = '';
$announcements_file = 'announcements.json';

// 处理表单提交
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['json_content'])) {
        $json_content = $_POST['json_content'];
        
        // 验证JSON格式
        $data = json_decode($json_content, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            $error = 'JSON格式错误: ' . json_last_error_msg();
        } else {
            // 保存到文件
            if (file_put_contents($announcements_file, $json_content)) {
                $message = '保存成功！更新时间: ' . date('Y-m-d H:i:s');
            } else {
                $error = '保存失败，请检查文件权限。';
            }
        }
    }
}

// 读取当前JSON文件内容
if (file_exists($announcements_file)) {
    $current_json = file_get_contents($announcements_file);
} else {
    $current_json = '{}';
    $error = '警告: 公告文件不存在，将创建新文件。';
}

// 美化JSON格式（便于编辑）
$current_json_pretty = json_encode(json_decode($current_json), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
?>
<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>公告管理</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            padding: 20px;
            background-color: #f7f7f7;
        }
        .container {
            max-width: 1000px;
            margin: 0 auto;
            background-color: #fff;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
            padding: 20px;
        }
        h1 {
            margin-bottom: 20px;
            color: #2c3e50;
            text-align: center;
        }
        .message {
            padding: 10px;
            margin-bottom: 20px;
            border-radius: 4px;
        }
        .success {
            background-color: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        .error {
            background-color: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        form {
            margin-bottom: 20px;
        }
        textarea {
            width: 100%;
            height: 500px;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-family: 'Courier New', monospace;
            font-size: 14px;
            resize: vertical;
        }
        .buttons {
            display: flex;
            justify-content: space-between;
            margin-top: 15px;
        }
        button {
            padding: 10px 15px;
            background-color: #3498db;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 16px;
        }
        button:hover {
            background-color: #2980b9;
        }
        .preview-btn {
            background-color: #2ecc71;
        }
        .preview-btn:hover {
            background-color: #27ae60;
        }
        .help {
            margin-top: 30px;
            background-color: #f8f9fa;
            padding: 15px;
            border-radius: 4px;
            border-left: 4px solid #3498db;
        }
        .help h2 {
            margin-bottom: 10px;
            color: #2c3e50;
        }
        .help p, .help ul {
            margin-bottom: 10px;
        }
        .help ul {
            margin-left: 20px;
        }
        .help code {
            background-color: #eee;
            padding: 2px 5px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
        }
        .markdown-section {
            margin-top: 20px;
            background-color: #f0f7ff;
            padding: 15px;
            border-radius: 4px;
            border-left: 4px solid #4285f4;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>公告管理页面</h1>
        
        <?php if ($message): ?>
            <div class="message success"><?php echo htmlspecialchars($message); ?></div>
        <?php endif; ?>
        
        <?php if ($error): ?>
            <div class="message error"><?php echo htmlspecialchars($error); ?></div>
        <?php endif; ?>
        
        <form method="post">
            <textarea name="json_content" id="json_content"><?php echo htmlspecialchars($current_json_pretty); ?></textarea>
            <div class="buttons">
                <button type="submit">保存更新</button>
                <a href="index.php" target="_blank" class="preview-btn" style="text-decoration:none; display:inline-block">预览公告</a>
            </div>
        </form>
        
        <div class="help">
            <h2>使用帮助</h2>
            <p>编辑上方JSON文件以更新公告内容。各字段说明如下：</p>
            <ul>
                <li><code>page_title</code>: 页面标题（浏览器标签显示）</li>
                <li><code>header_title</code>: 页面头部标题</li>
                <li><code>header_color</code>: 头部背景颜色（使用CSS颜色代码）</li>
                <li><code>last_updated</code>: 最后更新日期</li>
                <li><code>important_notice</code>: 重要通知区域（可选）
                    <ul>
                        <li><code>title</code>: 通知标题</li>
                        <li><code>content</code>: 通知内容（数组，每个元素为一段）</li>
                        <li><code>markdown</code>: 是否启用Markdown格式（true/false）</li>
                    </ul>
                </li>
                <li><code>announcements</code>: 公告列表（数组）
                    <ul>
                        <li><code>title</code>: 公告标题</li>
                        <li><code>date</code>: 公告日期</li>
                        <li><code>content</code>: 公告内容（数组，每个元素为一段）</li>
                        <li><code>markdown</code>: 是否启用Markdown格式（true/false）</li>
                    </ul>
                </li>
                <li><code>footer</code>: 页脚信息</li>
            </ul>
            <p>要添加新公告，在<code>announcements</code>数组的开头添加一个新对象。</p>
            <p>如不需要显示重要通知，可以设置<code>important_notice</code>为<code>null</code>或删除该字段。</p>
            
            <div class="markdown-section">
                <h2>Markdown 格式使用说明</h2>
                <p>设置 <code>markdown: true</code> 后，您可以在内容中使用 Markdown 语法：</p>
                <ul>
                    <li><code># 标题1</code>, <code>## 标题2</code>, <code>### 标题3</code> - 不同级别的标题</li>
                    <li><code>**粗体**</code>, <code>*斜体*</code> - 文本格式</li>
                    <li><code>- 项目1</code>, <code>1. 项目1</code> - 无序和有序列表</li>
                    <li><code>[链接文本](https://example.com)</code> - 链接</li>
                    <li><code>![图片描述](图片URL)</code> - 图片</li>
                    <li><code>```代码块```</code> - 代码块</li>
                    <li><code>`行内代码`</code> - 行内代码</li>
                    <li><code>> 引用文本</code> - 引用</li>
                </ul>
                <p>Markdown 内容示例：</p>
                <pre><code>
{
  "title": "Markdown示例公告",
  "date": "2025年4月6日",
  "markdown": true,
  "content": [
    "# 大标题\n\n这是一段正文，支持**粗体**和*斜体*。\n\n- 列表项目1\n- 列表项目2\n\n[链接文本](https://example.com)",
    "## 第二段\n\n这是第二段内容，使用不同的数组元素。"
  ]
}
                </code></pre>
            </div>
        </div>
    </div>
</body>
</html>
