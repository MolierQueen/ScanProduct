//
//  AllItemsViewController.swift
//  ScanProduct
//
//  Created by molier on 2025/9/7.
//

import UIKit
import MobileCoreServices

protocol AllItemsViewControllerDelegate: AnyObject {
    func deleteItem(forKey key: String)
    func updateDataDict(_ dataDict: [String: [String: String]])
}

class AllItemsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate {

    var dataDict: [String: [String: String]] = [:]
    weak var delegate: AllItemsViewControllerDelegate?
    let tableView = UITableView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
    }
    
    func setupUI() {
        // 导航返回按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "返回", style: .plain, target: self, action: #selector(dismissSelf))
        
        // 导入/导出按钮
        let importButton = UIBarButtonItem(title: "导入", style: .plain, target: self, action: #selector(importData))
        let exportButton = UIBarButtonItem(title: "导出", style: .plain, target: self, action: #selector(exportData))
        navigationItem.rightBarButtonItems = [exportButton, importButton]
        
        // TableView
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }
    
    @objc func dismissSelf() {
        dismiss(animated: true)
    }
    
    // MARK: - TableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataDict.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let key = Array(dataDict.keys)[indexPath.row]
        let value = dataDict[key]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let title = value?["title"] ?? ""
        let des = value?["des"] ?? ""
        cell.textLabel?.text = "\(title) - \(des)"
        return cell
    }
    
    // 左滑删除
    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let key = Array(dataDict.keys)[indexPath.row]
            delegate?.deleteItem(forKey: key)
            dataDict.removeValue(forKey: key)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            delegate?.updateDataDict(dataDict)
        }
    }
    
    func tableView(_ tableView: UITableView,
                   titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return "删除"
    }
    
    // MARK: - 导出功能
    @objc func exportData() {
        let fileURL = getScanDataFileURL()
        do {
            let data = try JSONSerialization.data(withJSONObject: dataDict, options: .prettyPrinted)
            try data.write(to: fileURL)
            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            present(activityVC, animated: true)
        } catch {
            showAlert(message: "导出失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 导入功能
    @objc func importData() {
        if #available(iOS 14.0, *) {
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json])
            picker.delegate = self
            picker.allowsMultipleSelection = false
            present(picker, animated: true)
        } else {
            // Fallback on earlier versions
        }
    }
    
    // MARK: - UIDocumentPickerDelegate
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        // Security-Scoped URL 访问
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try Data(contentsOf: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: [String: String]] {
                // 合并数据
                for (key, value) in json {
                    dataDict[key] = value
                }
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
                delegate?.updateDataDict(dataDict)
            } else {
                showAlert(message: "文件格式错误")
            }
        } catch {
            showAlert(message: "导入失败: \(error.localizedDescription)")
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // 用户取消，不处理
    }
    
    // MARK: - 工具方法
    func getScanDataFileURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("scanData.json")
    }
    
    func showAlert(message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            self.present(alert, animated: true)
        }
    }
}
