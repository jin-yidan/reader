import SwiftUI
import PDFKit

/// SwiftUI wrapper for PDFView with highlight click detection and text selection
public struct PDFViewerView: NSViewRepresentable {
    let document: PDFDocument?
    @Binding var selectedAnnotation: PDFAnnotation?
    @Binding var zoomScale: CGFloat
    let highlightColor: NSColor
    let onHighlightClicked: (PDFAnnotation, PDFPage) -> Void
    let onMultiLineHighlight: ([(page: PDFPage, bounds: CGRect)], String, NSColor) -> Void
    let onDeleteHighlight: (PDFAnnotation, PDFPage) -> Void

    public init(
        document: PDFDocument?,
        selectedAnnotation: Binding<PDFAnnotation?>,
        zoomScale: Binding<CGFloat>,
        highlightColor: NSColor = .yellow,
        onHighlightClicked: @escaping (PDFAnnotation, PDFPage) -> Void,
        onMultiLineHighlight: @escaping ([(page: PDFPage, bounds: CGRect)], String, NSColor) -> Void,
        onDeleteHighlight: @escaping (PDFAnnotation, PDFPage) -> Void
    ) {
        self.document = document
        self._selectedAnnotation = selectedAnnotation
        self._zoomScale = zoomScale
        self.highlightColor = highlightColor
        self.onHighlightClicked = onHighlightClicked
        self.onMultiLineHighlight = onMultiLineHighlight
        self.onDeleteHighlight = onDeleteHighlight
    }
    
    public func makeNSView(context: Context) -> PDFView {
        let pdfView = HighlightablePDFView()
        pdfView.autoScales = false
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.delegate = context.coordinator
        pdfView.highlightColor = highlightColor
        pdfView.onAnnotationClicked = { annotation, page in
            if annotation.type == "Highlight" {
                onHighlightClicked(annotation, page)
            }
        }
        pdfView.onMultiLineHighlight = onMultiLineHighlight
        pdfView.onDeleteHighlight = onDeleteHighlight
        
        if let document = document {
            pdfView.document = document
            pdfView.scaleFactor = zoomScale
        }
        
        return pdfView
    }
    
    public func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document
        }
        
        if let highlightablePDF = pdfView as? HighlightablePDFView {
            highlightablePDF.highlightColor = highlightColor
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, PDFViewDelegate {
        var parent: PDFViewerView
        
        init(_ parent: PDFViewerView) {
            self.parent = parent
        }
    }
}

/// Custom PDFView that supports highlighting via right-click and annotation clicks
class HighlightablePDFView: PDFView {
    var onAnnotationClicked: ((PDFAnnotation, PDFPage) -> Void)?
    var onMultiLineHighlight: (([(page: PDFPage, bounds: CGRect)], String, NSColor) -> Void)?
    var onDeleteHighlight: ((PDFAnnotation, PDFPage) -> Void)?
    var highlightColor: NSColor = .yellow

    private var translationPopover: NSPopover?
    private var glossaryPopover: NSPopover?
    
    override func mouseDown(with event: NSEvent) {
        // Always call super first to allow normal text selection
        super.mouseDown(with: event)
        
        // Then check if we clicked on an annotation (for single clicks after selection is done)
        if event.clickCount == 1 {
            let windowPoint = event.locationInWindow
            let viewPoint = convert(windowPoint, from: nil)
            
            if let page = page(for: viewPoint, nearest: true) {
                let pagePoint = convert(viewPoint, to: page)
                
                for annotation in page.annotations {
                    if annotation.bounds.contains(pagePoint) && annotation.type == "Highlight" {
                        onAnnotationClicked?(annotation, page)
                        return
                    }
                }
            }
        }
    }
    
    override func menu(for event: NSEvent) -> NSMenu? {
        let windowPoint = event.locationInWindow
        let viewPoint = convert(windowPoint, from: nil)
        
        // Check if there's a text selection
        if let selection = currentSelection,
           !selection.pages.isEmpty,
           let selectedText = selection.string,
           !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return createSelectionContextMenu()
        }
        
        // Check if we right-clicked on a highlight annotation
        if let page = page(for: viewPoint, nearest: true) {
            let pagePoint = convert(viewPoint, to: page)
            
            for annotation in page.annotations {
                if annotation.bounds.contains(pagePoint) && annotation.type == "Highlight" {
                    return createHighlightContextMenu(for: annotation, on: page)
                }
            }
        }
        
        return super.menu(for: event)
    }
    
    private func createSelectionContextMenu() -> NSMenu {
        let menu = NSMenu()

        // Quick highlight with current color (default action)
        let quickHighlight = NSMenuItem(title: "Highlight", action: #selector(highlightWithCurrentColor(_:)), keyEquivalent: "h")
        quickHighlight.target = self
        menu.addItem(quickHighlight)

        // Translate option
        let translateItem = NSMenuItem(title: "Translate", action: #selector(translateSelection(_:)), keyEquivalent: "t")
        translateItem.target = self
        menu.addItem(translateItem)

        // Add to Glossary option
        let glossaryItem = NSMenuItem(title: "Add to Glossary", action: #selector(addToGlossary(_:)), keyEquivalent: "g")
        glossaryItem.target = self
        menu.addItem(glossaryItem)

        menu.addItem(NSMenuItem.separator())

        // Color options - just color names
        let yellowItem = NSMenuItem(title: "Yellow", action: #selector(highlightYellow(_:)), keyEquivalent: "")
        yellowItem.target = self
        menu.addItem(yellowItem)

        let pinkItem = NSMenuItem(title: "Pink", action: #selector(highlightPink(_:)), keyEquivalent: "")
        pinkItem.target = self
        menu.addItem(pinkItem)

        let blueItem = NSMenuItem(title: "Blue", action: #selector(highlightBlue(_:)), keyEquivalent: "")
        blueItem.target = self
        menu.addItem(blueItem)

        let greenItem = NSMenuItem(title: "Green", action: #selector(highlightGreen(_:)), keyEquivalent: "")
        greenItem.target = self
        menu.addItem(greenItem)

        let orangeItem = NSMenuItem(title: "Orange", action: #selector(highlightOrange(_:)), keyEquivalent: "")
        orangeItem.target = self
        menu.addItem(orangeItem)

        return menu
    }
    
    private func createHighlightContextMenu(for annotation: PDFAnnotation, on page: PDFPage) -> NSMenu {
        let menu = NSMenu()
        
        let deleteItem = NSMenuItem(title: "Remove Highlight", action: #selector(removeHighlightAction(_:)), keyEquivalent: "")
        deleteItem.target = self
        deleteItem.representedObject = (annotation, page)
        menu.addItem(deleteItem)
        
        return menu
    }
    
    @objc private func highlightYellow(_ sender: NSMenuItem) {
        performHighlight(with: .systemYellow)
    }
    
    @objc private func highlightPink(_ sender: NSMenuItem) {
        performHighlight(with: .systemPink)
    }
    
    @objc private func highlightBlue(_ sender: NSMenuItem) {
        performHighlight(with: .systemBlue)
    }
    
    @objc private func highlightGreen(_ sender: NSMenuItem) {
        performHighlight(with: .systemGreen)
    }
    
    @objc private func highlightOrange(_ sender: NSMenuItem) {
        performHighlight(with: .systemOrange)
    }
    
    @objc private func highlightWithCurrentColor(_ sender: NSMenuItem) {
        performHighlight(with: highlightColor)
    }
    
    private func performHighlight(with color: NSColor) {
        guard let selection = currentSelection,
              let selectedText = selection.string,
              !selectedText.isEmpty else {
            return
        }

        // Get selection by line to handle multi-line selections properly
        let selectionsByLine = selection.selectionsByLine()

        // Collect all highlight bounds for multi-line
        var highlights: [(page: PDFPage, bounds: CGRect)] = []

        for lineSelection in selectionsByLine {
            guard let page = lineSelection.pages.first else { continue }
            let bounds = lineSelection.bounds(for: page)
            let lineText = lineSelection.string ?? ""

            if !lineText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                highlights.append((page: page, bounds: bounds))
            }
        }

        // Call with combined text, highlight bounds, and the selected color
        if !highlights.isEmpty {
            onMultiLineHighlight?(highlights, selectedText, color)
        }

        clearSelection()
    }
    
    @objc private func removeHighlightAction(_ sender: NSMenuItem) {
        guard let (annotation, page) = sender.representedObject as? (PDFAnnotation, PDFPage) else { return }
        onDeleteHighlight?(annotation, page)
    }

    // MARK: - Translation

    @objc private func translateSelection(_ sender: NSMenuItem) {
        guard let selection = currentSelection,
              let selectedText = selection.string,
              !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // Clean up text: replace multiple whitespace/newlines with single space
        let cleanedText = selectedText
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        showTranslationPopover(for: cleanedText)
    }

    private func showTranslationPopover(for text: String) {
        // Close existing popover
        translationPopover?.close()

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        let contentView = TranslationPopoverView(originalText: text)
        popover.contentViewController = NSHostingController(rootView: contentView)
        // Dynamic height based on text length
        let estimatedHeight = min(400, max(180, text.count / 3 + 120))
        popover.contentSize = NSSize(width: 320, height: CGFloat(estimatedHeight))

        // Show popover at mouse location
        if let window = self.window {
            let mouseLocation = window.mouseLocationOutsideOfEventStream
            let viewPoint = convert(mouseLocation, from: nil)
            let rect = NSRect(x: viewPoint.x, y: viewPoint.y, width: 1, height: 1)
            popover.show(relativeTo: rect, of: self, preferredEdge: .maxY)
        }

        translationPopover = popover
    }

    // MARK: - Glossary

    @objc private func addToGlossary(_ sender: NSMenuItem) {
        guard let selection = currentSelection,
              let selectedText = selection.string,
              !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let cleanedText = selectedText
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        showGlossaryPopover(for: cleanedText)
    }

    private func showGlossaryPopover(for text: String) {
        glossaryPopover?.close()

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        let contentView = GlossaryAddView(englishTerm: text) {
            popover.close()
        }
        popover.contentViewController = NSHostingController(rootView: contentView)
        popover.contentSize = NSSize(width: 280, height: 140)

        if let window = self.window {
            let mouseLocation = window.mouseLocationOutsideOfEventStream
            let viewPoint = convert(mouseLocation, from: nil)
            let rect = NSRect(x: viewPoint.x, y: viewPoint.y, width: 1, height: 1)
            popover.show(relativeTo: rect, of: self, preferredEdge: .maxY)
        }

        glossaryPopover = popover
    }
}

// MARK: - Glossary Add View

struct GlossaryAddView: View {
    let englishTerm: String
    let onDismiss: () -> Void

    @State private var chineseTranslation: String = ""
    @State private var saved = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // English term (read-only)
            VStack(alignment: .leading, spacing: 4) {
                Text("English")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Text(englishTerm)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }

            // Chinese input
            VStack(alignment: .leading, spacing: 4) {
                Text("Chinese")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("Enter Chinese translation", text: $chineseTranslation)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        saveToGlossary()
                    }
            }

            // Save button
            HStack {
                Spacer()
                if saved {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                        Text("Saved")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.green)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else {
                    Button(action: saveToGlossary) {
                        Text("Save")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(chineseTranslation.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .animation(.easeOut(duration: 0.15), value: saved)
        }
        .padding(16)
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            // Check if term already exists in custom glossary
            if let existing = CustomGlossary.shared.getTranslation(for: englishTerm) {
                chineseTranslation = existing
            }
            // Auto-focus the text field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }

    private func saveToGlossary() {
        let trimmed = chineseTranslation.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        CustomGlossary.shared.addTerm(english: englishTerm, chinese: trimmed)
        saved = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            onDismiss()
        }
    }
}

// MARK: - Custom Glossary Storage

class CustomGlossary {
    static let shared = CustomGlossary()
    private let userDefaultsKey = "custom_glossary"

    private init() {}

    /// Get all custom terms
    var terms: [String: String] {
        UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: String] ?? [:]
    }

    /// Add or update a term
    func addTerm(english: String, chinese: String) {
        var current = terms
        current[english.lowercased()] = chinese
        UserDefaults.standard.set(current, forKey: userDefaultsKey)
    }

    /// Remove a term
    func removeTerm(english: String) {
        var current = terms
        current.removeValue(forKey: english.lowercased())
        UserDefaults.standard.set(current, forKey: userDefaultsKey)
    }

    /// Get translation for a term
    func getTranslation(for english: String) -> String? {
        return terms[english.lowercased()]
    }
}

// MARK: - Terminology Glossary

/// Built-in glossary for ML/AI/Math/Coding terminology
/// Maps English terms to preferred Chinese translations
enum TerminologyGlossary {
    static let terms: [String: String] = [
        // Machine Learning - Core Concepts
        "machine learning": "机器学习",
        "deep learning": "深度学习",
        "neural network": "神经网络",
        "artificial intelligence": "人工智能",
        "reinforcement learning": "强化学习",
        "supervised learning": "监督学习",
        "unsupervised learning": "无监督学习",
        "semi-supervised": "半监督",
        "self-supervised": "自监督",
        "transfer learning": "迁移学习",
        "federated learning": "联邦学习",
        "meta-learning": "元学习",
        "few-shot learning": "小样本学习",
        "zero-shot": "零样本",
        "one-shot": "单样本",
        "contrastive learning": "对比学习",
        "representation learning": "表示学习",
        "feature learning": "特征学习",
        "end-to-end": "端到端",

        // Neural Network Architecture
        "transformer": "Transformer",
        "attention mechanism": "注意力机制",
        "self-attention": "自注意力",
        "multi-head attention": "多头注意力",
        "cross-attention": "交叉注意力",
        "feedforward": "前馈",
        "feed-forward": "前馈",
        "convolutional": "卷积",
        "convolution": "卷积",
        "recurrent": "循环",
        "residual": "残差",
        "skip connection": "跳跃连接",
        "bottleneck": "瓶颈层",
        "encoder": "编码器",
        "decoder": "解码器",
        "embedding": "嵌入",
        "embeddings": "嵌入向量",
        "latent space": "潜在空间",
        "latent": "潜在",
        "hidden layer": "隐藏层",
        "hidden state": "隐藏状态",
        "pooling": "池化",
        "max pooling": "最大池化",
        "average pooling": "平均池化",
        "dropout": "Dropout",
        "batch normalization": "批归一化",
        "layer normalization": "层归一化",
        "normalization": "归一化",

        // Model Types
        "large language model": "大语言模型",
        "language model": "语言模型",
        "generative model": "生成模型",
        "discriminative model": "判别模型",
        "autoencoder": "自编码器",
        "variational autoencoder": "变分自编码器",
        "GAN": "生成对抗网络",
        "generative adversarial": "生成对抗",
        "diffusion model": "扩散模型",
        "foundation model": "基础模型",
        "pretrained model": "预训练模型",
        "pre-trained": "预训练",
        "fine-tuning": "微调",
        "fine-tune": "微调",
        "BERT": "BERT",
        "GPT": "GPT",
        "LSTM": "长短期记忆网络",
        "RNN": "循环神经网络",
        "CNN": "卷积神经网络",
        "MLP": "多层感知机",
        "perceptron": "感知机",

        // Training & Optimization
        "training": "训练",
        "inference": "推理",
        "forward pass": "前向传播",
        "backward pass": "反向传播",
        "backpropagation": "反向传播",
        "gradient descent": "梯度下降",
        "stochastic gradient descent": "随机梯度下降",
        "SGD": "随机梯度下降",
        "Adam": "Adam优化器",
        "optimizer": "优化器",
        "learning rate": "学习率",
        "loss function": "损失函数",
        "cost function": "代价函数",
        "objective function": "目标函数",
        "cross-entropy": "交叉熵",
        "cross entropy": "交叉熵",
        "mean squared error": "均方误差",
        "MSE": "均方误差",
        "regularization": "正则化",
        "L1 regularization": "L1正则化",
        "L2 regularization": "L2正则化",
        "weight decay": "权重衰减",
        "momentum": "动量",
        "batch size": "批大小",
        "mini-batch": "小批量",
        "epoch": "轮次",
        "iteration": "迭代",
        "convergence": "收敛",
        "overfitting": "过拟合",
        "underfitting": "欠拟合",
        "generalization": "泛化",
        "early stopping": "早停",
        "checkpoint": "检查点",
        "warmup": "预热",
        "scheduler": "调度器",
        "annealing": "退火",

        // Evaluation & Metrics
        "accuracy": "准确率",
        "precision": "精确率",
        "recall": "召回率",
        "F1 score": "F1分数",
        "AUC": "AUC",
        "ROC curve": "ROC曲线",
        "confusion matrix": "混淆矩阵",
        "true positive": "真正例",
        "false positive": "假正例",
        "true negative": "真负例",
        "false negative": "假负例",
        "validation": "验证",
        "test set": "测试集",
        "training set": "训练集",
        "validation set": "验证集",
        "cross-validation": "交叉验证",
        "k-fold": "k折",
        "holdout": "留出法",
        "benchmark": "基准测试",
        "baseline": "基线",
        "BLEU": "BLEU",
        "perplexity": "困惑度",
        "ablation study": "消融实验",
        "ablation": "消融",

        // NLP Specific
        "natural language processing": "自然语言处理",
        "NLP": "自然语言处理",
        "tokenization": "分词",
        "tokenizer": "分词器",
        "token": "词元",
        "tokens": "词元",
        "vocabulary": "词汇表",
        "word embedding": "词嵌入",
        "word2vec": "Word2Vec",
        "sequence-to-sequence": "序列到序列",
        "seq2seq": "序列到序列",
        "sentiment analysis": "情感分析",
        "named entity recognition": "命名实体识别",
        "NER": "命名实体识别",
        "part-of-speech": "词性标注",
        "POS tagging": "词性标注",
        "parsing": "句法分析",
        "dependency parsing": "依存句法分析",
        "coreference": "共指消解",
        "machine translation": "机器翻译",
        "text generation": "文本生成",
        "language understanding": "语言理解",
        "reading comprehension": "阅读理解",
        "question answering": "问答",
        "summarization": "摘要",
        "paraphrase": "复述",
        "prompt": "提示词",
        "prompting": "提示",
        "in-context learning": "上下文学习",
        "chain-of-thought": "思维链",
        "reasoning": "推理",

        // Computer Vision
        "computer vision": "计算机视觉",
        "image classification": "图像分类",
        "object detection": "目标检测",
        "semantic segmentation": "语义分割",
        "instance segmentation": "实例分割",
        "image segmentation": "图像分割",
        "bounding box": "边界框",
        "anchor box": "锚框",
        "feature map": "特征图",
        "receptive field": "感受野",
        "stride": "步幅",
        "padding": "填充",
        "kernel": "卷积核",
        "filter": "滤波器",
        "upsampling": "上采样",
        "downsampling": "下采样",
        "data augmentation": "数据增强",
        "image recognition": "图像识别",
        "face recognition": "人脸识别",
        "pose estimation": "姿态估计",
        "optical flow": "光流",

        // Math & Statistics
        "gradient": "梯度",
        "derivative": "导数",
        "partial derivative": "偏导数",
        "Jacobian": "雅可比矩阵",
        "Hessian": "海森矩阵",
        "eigenvalue": "特征值",
        "eigenvector": "特征向量",
        "matrix": "矩阵",
        "vector": "向量",
        "tensor": "张量",
        "scalar": "标量",
        "dot product": "点积",
        "inner product": "内积",
        "outer product": "外积",
        "matrix multiplication": "矩阵乘法",
        "transpose": "转置",
        "inverse": "逆",
        "determinant": "行列式",
        "rank": "秩",
        "norm": "范数",
        "L1 norm": "L1范数",
        "L2 norm": "L2范数",
        "Euclidean": "欧几里得",
        "cosine similarity": "余弦相似度",
        "probability": "概率",
        "distribution": "分布",
        "Gaussian": "高斯",
        "normal distribution": "正态分布",
        "Bernoulli": "伯努利",
        "multinomial": "多项式",
        "categorical": "分类",
        "prior": "先验",
        "posterior": "后验",
        "likelihood": "似然",
        "maximum likelihood": "最大似然",
        "Bayesian": "贝叶斯",
        "expectation": "期望",
        "variance": "方差",
        "covariance": "协方差",
        "standard deviation": "标准差",
        "mean": "均值",
        "median": "中位数",
        "mode": "众数",
        "entropy": "熵",
        "KL divergence": "KL散度",
        "Kullback-Leibler": "KL散度",
        "mutual information": "互信息",
        "information theory": "信息论",
        "sampling": "采样",
        "Monte Carlo": "蒙特卡洛",
        "Markov chain": "马尔可夫链",
        "random variable": "随机变量",
        "i.i.d.": "独立同分布",
        "hypothesis": "假设",
        "null hypothesis": "零假设",
        "p-value": "p值",
        "confidence interval": "置信区间",
        "significance": "显著性",
        "correlation": "相关性",
        "regression": "回归",
        "linear regression": "线性回归",
        "logistic regression": "逻辑回归",
        "polynomial": "多项式",
        "interpolation": "插值",
        "extrapolation": "外推",
        "approximation": "近似",
        "optimization": "优化",
        "convex": "凸",
        "non-convex": "非凸",
        "local minimum": "局部最小值",
        "global minimum": "全局最小值",
        "saddle point": "鞍点",
        "constraint": "约束",
        "Lagrangian": "拉格朗日",

        // Programming & CS
        "algorithm": "算法",
        "data structure": "数据结构",
        "complexity": "复杂度",
        "time complexity": "时间复杂度",
        "space complexity": "空间复杂度",
        "Big O": "大O",
        "recursion": "递归",
        "loop": "循环",
        "function": "函数",
        "variable": "变量",
        "parameter": "参数",
        "argument": "参数",
        "hyperparameter": "超参数",
        "return value": "返回值",
        "class": "类",
        "object": "对象",
        "instance": "实例",
        "method": "方法",
        "attribute": "属性",
        "inheritance": "继承",
        "polymorphism": "多态",
        "encapsulation": "封装",
        "abstraction": "抽象",
        "interface": "接口",
        "API": "API",
        "library": "库",
        "framework": "框架",
        "module": "模块",
        "package": "包",
        "dependency": "依赖",
        "version": "版本",
        "debug": "调试",
        "bug": "漏洞",
        "error": "错误",
        "exception": "异常",
        "stack trace": "堆栈跟踪",
        "memory": "内存",
        "heap": "堆",
        "stack": "栈",
        "pointer": "指针",
        "reference": "引用",
        "garbage collection": "垃圾回收",
        "thread": "线程",
        "process": "进程",
        "concurrency": "并发",
        "parallelism": "并行",
        "asynchronous": "异步",
        "synchronous": "同步",
        "callback": "回调",
        "cache": "缓存",
        "buffer": "缓冲区",
        "queue": "队列",
        "hash": "哈希",
        "hash table": "哈希表",
        "binary tree": "二叉树",
        "graph": "图",
        "node": "节点",
        "edge": "边",
        "traversal": "遍历",
        "search": "搜索",
        "sort": "排序",
        "binary search": "二分查找",
        "dynamic programming": "动态规划",
        "greedy": "贪心",
        "divide and conquer": "分治",
        "brute force": "暴力",

        // Deep Learning Frameworks & Tools
        "PyTorch": "PyTorch",
        "TensorFlow": "TensorFlow",
        "Keras": "Keras",
        "NumPy": "NumPy",
        "pandas": "pandas",
        "scikit-learn": "scikit-learn",
        "GPU": "GPU",
        "CUDA": "CUDA",
        "TPU": "TPU",
        "distributed training": "分布式训练",
        "model parallelism": "模型并行",
        "data parallelism": "数据并行",
        "mixed precision": "混合精度",
        "quantization": "量化",
        "pruning": "剪枝",
        "distillation": "蒸馏",
        "knowledge distillation": "知识蒸馏",

        // Data & Datasets
        "dataset": "数据集",
        "data": "数据",
        "label": "标签",
        "annotation": "标注",
        "ground truth": "真实标签",
        "feature": "特征",
        "feature extraction": "特征提取",
        "feature engineering": "特征工程",
        "dimensionality reduction": "降维",
        "PCA": "主成分分析",
        "principal component": "主成分",
        "clustering": "聚类",
        "k-means": "K均值",
        "classification": "分类",
        "multi-class": "多分类",
        "binary classification": "二分类",
        "multi-label": "多标签",
        "imbalanced": "不平衡",
        "class imbalance": "类别不平衡",
        "oversampling": "过采样",
        "undersampling": "欠采样",
        "noise": "噪声",
        "outlier": "异常值",
        "missing value": "缺失值",
        "preprocessing": "预处理",
        "postprocessing": "后处理",
        "pipeline": "流水线",
        "workflow": "工作流",
    ]

    // MARK: - Cached Data for Performance

    /// Cached sorted terms (sorted by length, longer first)
    private static let sortedBuiltInTerms: [(key: String, value: String)] = {
        terms.map { ($0.key, $0.value) }.sorted { $0.key.count > $1.key.count }
    }()

    /// Apply glossary corrections to translated text
    /// Searches original English text for terms and ensures correct Chinese translation
    /// Custom user terms take priority over built-in terms
    static func apply(to translation: String, original: String) -> String {
        var result = translation
        let lowerOriginal = original.lowercased()

        // Quick exit if translation or original is too short
        guard !translation.isEmpty, original.count >= 2 else { return result }

        // Extract words from original for quick membership test
        let originalWords = Set(lowerOriginal.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty })

        // Get custom terms (these always take priority and are checked first)
        let customTerms = CustomGlossary.shared.terms
        let sortedCustomTerms = customTerms.sorted { $0.key.count > $1.key.count }

        // Process custom terms first (they have priority)
        for (english, chinese) in sortedCustomTerms {
            let lowerEnglish = english.lowercased()
            // Quick word-based check before expensive contains
            let termWords = lowerEnglish.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            let hasMatchingWord = termWords.contains { originalWords.contains($0) }

            if hasMatchingWord && lowerOriginal.contains(lowerEnglish) {
                let commonMistranslations = getCommonMistranslations(for: english)
                for mistranslation in commonMistranslations {
                    result = result.replacingOccurrences(of: mistranslation, with: chinese)
                }
            }
        }

        // Process built-in terms (use cached sorted list)
        for (english, chinese) in sortedBuiltInTerms {
            // Skip if custom term already handles this
            if customTerms[english.lowercased()] != nil { continue }

            // Quick word-based check before expensive contains
            let termWords = english.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            let hasMatchingWord = termWords.contains { originalWords.contains($0) }

            if hasMatchingWord && lowerOriginal.contains(english) {
                let commonMistranslations = getCommonMistranslations(for: english)
                for mistranslation in commonMistranslations {
                    result = result.replacingOccurrences(of: mistranslation, with: chinese)
                }
            }
        }

        return result
    }

    /// Get common mistranslations for a term that should be corrected
    private static func getCommonMistranslations(for term: String) -> [String] {
        // Map of terms to their common mistranslations
        let mistranslationMap: [String: [String]] = [
            "transformer": ["变压器", "转换器", "变换器"],
            "attention": ["注意", "关注"],
            "token": ["令牌", "代币", "符号"],
            "embedding": ["嵌入式", "镶嵌"],
            "gradient": ["坡度", "渐变"],
            "epoch": ["时代", "纪元", "时期"],
            "batch": ["批次", "一批"],
            "loss": ["损失", "亏损", "失去"],
            "feature": ["功能", "特点", "特色"],
            "layer": ["层次", "图层"],
            "model": ["模特", "模范"],
            "training": ["培训", "训练中"],
            "inference": ["推断", "推论"],
            "parameter": ["参量"],
            "weight": ["重量", "体重"],
            "bias": ["偏见", "偏差"],
            "activation": ["激活", "活化"],
            "pooling": ["合并", "汇集"],
            "sampling": ["抽样"],
            "distribution": ["分配", "发行", "分发"],
            "optimization": ["优化", "最佳化"],
            "convergence": ["汇合", "聚合"],
            "regularization": ["规范化", "正规化"],
            "normalization": ["标准化", "规范化"],
            "backbone": ["骨干", "主干"],
            "fine-tuning": ["精调", "细调"],
            "pretrained": ["预先训练"],
            "benchmark": ["标杆", "基准"],
            "baseline": ["底线", "基准线"],
            "pipeline": ["管道", "管线"],
            "framework": ["框架", "架构"],
            "neural": ["神经的", "神经性"],
            "network": ["网络", "网路"],
            "learning": ["学习中", "了解"],
            "supervised": ["监督的", "监管的"],
            "unsupervised": ["无监督的", "未监督"],
            "reinforcement": ["增强", "加强"],
            "generative": ["生成的", "生殖的"],
            "discriminative": ["判别的", "歧视性"],
            "recurrent": ["复发", "反复"],
            "convolutional": ["卷积的"],
            "residual": ["残余", "剩余"],
            "attention mechanism": ["注意机制", "关注机制"],
            "self-attention": ["自我关注", "自注意"],
        ]

        return mistranslationMap[term.lowercased()] ?? []
    }
}

// MARK: - Translation Popover View

import Translation

struct TranslationPopoverView: View {
    let originalText: String
    @State private var translatedText: String = ""
    @State private var isLoading = true
    @State private var copied = false
    @State private var triggerTranslation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Original text with accent bar
                    HStack(alignment: .top, spacing: 12) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: 3)

                        Text("\"\(originalText)\"")
                            .font(.system(size: 13, weight: .regular, design: .serif))
                            .foregroundColor(.primary.opacity(0.7))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Divider()
                        .padding(.vertical, 12)

                    // Translation
                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Translating...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .transition(.opacity)
                    } else {
                        Text(translatedText)
                            .font(.system(size: 13))
                            .foregroundColor(.primary.opacity(0.9))
                            .lineSpacing(4)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .animation(.easeOut(duration: 0.2), value: isLoading)
            }

            // Footer with copy button
            if !isLoading && !translatedText.isEmpty && !translatedText.contains("Download") && !translatedText.contains("Requires") {
                Divider()
                    .padding(.top, 8)
                HStack {
                    Spacer()
                    Button(action: copyTranslation) {
                        HStack(spacing: 4) {
                            if copied {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            Text(copied ? "Copied" : "Copy")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(copied ? .green : .accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(copied)
                    .animation(.easeOut(duration: 0.15), value: copied)
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            triggerTranslation = true
        }
        .animation(.easeOut(duration: 0.2), value: isLoading)
        .modifier(AppleTranslationModifier(
            originalText: originalText,
            translatedText: $translatedText,
            isLoading: $isLoading,
            shouldTranslate: $triggerTranslation
        ))
    }

    private func copyTranslation() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translatedText, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }
}

struct AppleTranslationModifier: ViewModifier {
    let originalText: String
    @Binding var translatedText: String
    @Binding var isLoading: Bool
    @Binding var shouldTranslate: Bool

    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content
                .translationTask(shouldTranslate ? .init(source: Locale.Language(identifier: "en"), target: Locale.Language(identifier: "zh-Hans")) : nil, action: { session in
                    do {
                        // Pre-process: replace glossary terms with placeholders
                        let (processedText, replacements) = GlossaryProcessor.preProcess(originalText)

                        let response = try await session.translate(processedText)

                        await MainActor.run {
                            // Post-process: restore placeholders with correct Chinese
                            var result = GlossaryProcessor.postProcess(response.targetText, replacements: replacements)
                            // Also apply mistranslation corrections for built-in terms
                            result = TerminologyGlossary.apply(to: result, original: originalText)
                            translatedText = result
                            isLoading = false
                        }
                    } catch {
                        await MainActor.run {
                            translatedText = "Download Chinese language pack in System Settings → General → Language & Region"
                            isLoading = false
                        }
                    }
                })
        } else {
            content
                .onChange(of: shouldTranslate) { newValue in
                    if newValue {
                        translatedText = "Requires macOS 15.0+"
                        isLoading = false
                    }
                }
        }
    }
}

// MARK: - Glossary Processor

/// Handles pre/post processing for glossary term replacement
enum GlossaryProcessor {
    /// Pre-process text: replace glossary terms with placeholders
    /// Returns the processed text and a mapping of placeholders to Chinese translations
    static func preProcess(_ text: String) -> (String, [String: String]) {
        var result = text
        var replacements: [String: String] = [:]

        // Get custom terms (these get placeholder treatment)
        let customTerms = CustomGlossary.shared.terms

        // Sort by length (longer first) to handle overlapping terms
        let sortedTerms = customTerms.sorted { $0.key.count > $1.key.count }

        var index = 0
        for (english, chinese) in sortedTerms {
            // Case-insensitive search and replace
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: english))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                let matches = regex.matches(in: result, options: [], range: range)

                // Replace from end to start to preserve indices
                for match in matches.reversed() {
                    if let matchRange = Range(match.range, in: result) {
                        let placeholder = "⟦\(index)⟧"
                        replacements[placeholder] = chinese
                        result.replaceSubrange(matchRange, with: placeholder)
                        index += 1
                    }
                }
            }
        }

        return (result, replacements)
    }

    /// Post-process translation: replace placeholders with correct Chinese
    static func postProcess(_ translation: String, replacements: [String: String]) -> String {
        var result = translation

        for (placeholder, chinese) in replacements {
            result = result.replacingOccurrences(of: placeholder, with: chinese)
        }

        return result
    }
}

// MARK: - Navigation Extension

public extension PDFView {
    /// Navigate to a specific annotation
    func navigateTo(annotation: PDFAnnotation, on page: PDFPage) {
        go(to: page)
        
        // Scroll to the annotation
        let destination = PDFDestination(page: page, at: CGPoint(x: annotation.bounds.minX, y: annotation.bounds.maxY))
        go(to: destination)
    }
    
    /// Navigate to a specific note
    func navigateTo(note: NoteAnnotation, in document: PDFDocument) {
        guard let page = document.page(at: note.pageIndex) else { return }
        
        go(to: page)
        
        let destination = PDFDestination(page: page, at: CGPoint(x: note.bounds.minX, y: note.bounds.maxY))
        go(to: destination)
    }
}
