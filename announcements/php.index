<?php
// 读取JSON配置文件
$announcements_json = file_get_contents('announcements.json');
$data = json_decode($announcements_json, true);

// 检查JSON解析是否出错
if (json_last_error() !== JSON_ERROR_NONE) {
    $error_message = 'JSON解析错误: ' . json_last_error_msg();
}

// 引入Parsedown类（如果文件存在）
$parsedown = null;
if (file_exists('Parsedown.php')) {
    require_once 'Parsedown.php';
    $parsedown = new Parsedown();
    $parsedown->setSafeMode(true); // 启用安全模式，防止XSS攻击
}
?>
<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo htmlspecialchars($data['page_title'] ?? '公告板'); ?></title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            background-color: #f7f7f7;
            padding: 20px;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background-color: #fff;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
            overflow: hidden;
        }
        header {
            background-color: <?php echo htmlspecialchars($data['header_color'] ?? '#3498db'); ?>;
            color: white;
            padding: 20px;
            text-align: center;
        }
        h1 {
            margin-bottom: 10px;
            font-size: 28px;
        }
        .last-updated {
            font-size: 14px;
            color: rgba(255, 255, 255, 0.8);
        }
        .content {
            padding: 30px;
        }
        .announcement {
            margin-bottom: 30px;
            border-bottom: 1px solid #eee;
            padding-bottom: 20px;
        }
        .announcement:last-child {
            border-bottom: none;
            margin-bottom: 0;
        }
        .announcement h2 {
            font-size: 22px;
            color: #2c3e50;
            margin-bottom: 10px;
        }
        .announcement .date {
            font-size: 14px;
            color: #7f8c8d;
            margin-bottom: 10px;
        }
        .announcement p {
            margin-bottom: 15px;
        }
        .announcement p:last-child,
        .markdown-content > *:last-child {
            margin-bottom: 0;
        }
        .important {
            background-color: #ffebee;
            border-left: 4px solid #f44336;
            padding: 15px;
            margin-bottom: 20px;
        }
        footer {
            text-align: center;
            padding: 20px;
            color: #7f8c8d;
            font-size: 14px;
            background-color: #f9f9f9;
            border-top: 1px solid #eee;
        }
        .error {
            background-color: #f44336;
            color: white;
            padding: 15px;
            margin-bottom: 20px;
            border-radius: 5px;
        }
        
        /* Markdown 样式 */
        .markdown-content {
            line-height: 1.6;
        }
        .markdown-content h1,
        .markdown-content h2,
        .markdown-content h3,
        .markdown-content h4,
        .markdown-content h5,
        .markdown-content h6 {
            margin-top: 1em;
            margin-bottom: 0.5em;
            color: #2c3e50;
        }
        .markdown-content ul,
        .markdown-content ol {
            margin-left: 2em;
            margin-bottom: 15px;
        }
        .markdown-content pre,
        .markdown-content code {
            background-color: #f5f5f5;
            border-radius: 3px;
            font-family: monospace;
        }
        .markdown-content pre {
            padding: 10px;
            overflow-x: auto;
            margin-bottom: 15px;
        }
        .markdown-content code {
            padding: 2px 4px;
        }
        .markdown-content blockquote {
            border-left: 4px solid #ddd;
            padding-left: 15px;
            color: #666;
            margin-bottom: 15px;
        }
        .markdown-content img {
            max-width: 100%;
            height: auto;
        }
        .markdown-content table {
            border-collapse: collapse;
            width: 100%;
            margin-bottom: 15px;
        }
        .markdown-content th,
        .markdown-content td {
            border: 1px solid #ddd;
            padding: 8px;
            text-align: left;
        }
        .markdown-content th {
            background-color: #f2f2f2;
        }
        
        @media (max-width: 600px) {
            header {
                padding: 15px;
            }
            h1 {
                font-size: 24px;
            }
            .content {
                padding: 20px;
            }
            .announcement h2 {
                font-size: 20px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1><?php echo htmlspecialchars($data['header_title'] ?? '公告板'); ?></h1>
            <div class="last-updated">最后更新: <?php echo htmlspecialchars($data['last_updated'] ?? date('Y年m月d日')); ?></div>
        </header>
        
        <div class="content">
            <?php if (isset($error_message)): ?>
                <div class="error">
                    <p><?php echo htmlspecialchars($error_message); ?></p>
                </div>
            <?php endif; ?>

            <?php if (isset($data['important_notice']) && !empty($data['important_notice'])): ?>
                <div class="important">
                    <h2><?php echo htmlspecialchars($data['important_notice']['title']); ?></h2>
                    <?php if (isset($data['important_notice']['markdown']) && $data['important_notice']['markdown'] === true && $parsedown !== null): ?>
                        <div class="markdown-content">
                            <?php echo $parsedown->text(implode("\n\n", $data['important_notice']['content'])); ?>
                        </div>
                    <?php else: ?>
                        <?php foreach ($data['important_notice']['content'] as $paragraph): ?>
                            <p><?php echo htmlspecialchars($paragraph); ?></p>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </div>
            <?php endif; ?>
            
            <?php if (isset($data['announcements']) && is_array($data['announcements'])): ?>
                <?php foreach ($data['announcements'] as $announcement): ?>
                    <div class="announcement">
                        <h2><?php echo htmlspecialchars($announcement['title']); ?></h2>
                        <div class="date"><?php echo htmlspecialchars($announcement['date']); ?></div>
                        <?php if (isset($announcement['markdown']) && $announcement['markdown'] === true && $parsedown !== null): ?>
                            <div class="markdown-content">
                                <?php echo $parsedown->text(implode("\n\n", $announcement['content'])); ?>
                            </div>
                        <?php else: ?>
                            <?php foreach ($announcement['content'] as $paragraph): ?>
                                <p><?php echo htmlspecialchars($paragraph); ?></p>
                            <?php endforeach; ?>
                        <?php endif; ?>
                    </div>
                <?php endforeach; ?>
            <?php endif; ?>
        </div>
        
        <footer>
            <p><?php echo htmlspecialchars($data['footer'] ?? '© ' . date('Y') . ' 公告发布系统 | 有任何问题请联系管理员'); ?></p>
        </footer>
    </div>
</body>
</html>
