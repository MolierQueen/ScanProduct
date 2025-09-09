//
//  ViewController.swift
//  ScanProduct
//
//  Created by molier on 2025/9/7.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    let titleLabel = UILabel()
    let desLabel = UILabel()
    let scanCodeButton = UIButton(type: .system)
    let viewAllButton = UIButton(type: .system)
    
    var currentKey: String?
    var dataDict: [String: [String: String]] = [:]
    
    let dataFileURL: URL = {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docDir.appendingPathComponent("scanData.json")
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
        loadData()
    }
    
    func setupUI() {
        titleLabel.text = "物品名称"
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        desLabel.text = "物品用途"
        desLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(desLabel)
        
        scanCodeButton.setTitle("Scan Code", for: .normal)
        scanCodeButton.addTarget(self, action: #selector(scanCode), for: .touchUpInside)
        scanCodeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scanCodeButton)

        viewAllButton.setTitle("查看所有物品", for: .normal)
        viewAllButton.addTarget(self, action: #selector(showAllItems), for: .touchUpInside)
        viewAllButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(viewAllButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            desLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            desLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            scanCodeButton.topAnchor.constraint(equalTo: desLabel.bottomAnchor, constant: 40),
            scanCodeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            viewAllButton.topAnchor.constraint(equalTo: scanCodeButton.bottomAnchor, constant: 20),
            viewAllButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }
    
    func loadData() {
        if let data = try? Data(contentsOf: dataFileURL),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: [String: String]] {
            dataDict = dict
        }
    }
    
    func saveData() {
        if let data = try? JSONSerialization.data(withJSONObject: dataDict, options: .prettyPrinted) {
            try? data.write(to: dataFileURL)
        }
    }
    
    // MARK: - Scan Code
    @objc func scanCode() {
        let scannerVC = ScannerViewController()
        scannerVC.delegate = self
        present(scannerVC, animated: true)
    }
    
    // MARK: - Delete Current Item
    @objc func deleteCurrentItem() {
        guard let key = currentKey else { return }
        dataDict.removeValue(forKey: key)
        saveData()
        titleLabel.text = "Title"
        desLabel.text = "Description"
//        deleteButton.isEnabled = false
        currentKey = nil
    }
    
    // MARK: - View All Items
    @objc func showAllItems() {
        let listVC = AllItemsViewController()
        listVC.dataDict = dataDict
        listVC.delegate = self
        let nav = UINavigationController(rootViewController: listVC)
        present(nav, animated: true)
    }
}

// MARK: - Scanner Delegate
extension ViewController: ScannerViewControllerDelegate {
    func didScan(code: String) {
        currentKey = code
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            if let value = self.dataDict[code] {
                self.titleLabel.text = value["title"]
                self.desLabel.text = value["des"]
//                self.deleteButton.isEnabled = true
            } else {
                let alert = UIAlertController(title: "请录入信息", message: nil, preferredStyle: .alert)
                alert.addTextField { $0.placeholder = "title" }
                alert.addTextField { $0.placeholder = "des" }
                alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { _ in
                    guard let title = alert.textFields?[0].text,
                          let des = alert.textFields?[1].text else { return }
                    self.dataDict[code] = ["title": title, "des": des]
                    self.saveData()
                    self.titleLabel.text = title
                    self.desLabel.text = des
//                    self.deleteButton.isEnabled = true
                }))
                self.present(alert, animated: true)
            }
        }
    }
}

// MARK: - AllItems Delegate
extension ViewController: AllItemsViewControllerDelegate {
    func updateDataDict(_ dataDict: [String : [String : String]]) {
        // 1. 更新主界面的本地数据
         self.dataDict = dataDict
         
         // 3. 保存到本地 JSON 文件，以便下次启动使用
         saveDataDictToFile(dataDict)
    }
    // 保存方法示例
    func saveDataDictToFile(_ dataDict: [String: [String: String]]) {
        let fileURL = getScanDataFileURL()
        do {
            let data = try JSONSerialization.data(withJSONObject: dataDict, options: .prettyPrinted)
            try data.write(to: fileURL)
        } catch {
            print("保存 scanData.json 失败: \(error)")
        }
    }

    // 获取 scanData.json 的路径
    func getScanDataFileURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("scanData.json")
    }
    
    func deleteItem(forKey key: String) {
        guard dataDict[key] != nil else { return }
        dataDict.removeValue(forKey: key)
        saveData()
        
        if currentKey == key {
            titleLabel.text = "Title"
            desLabel.text = "Description"
//            deleteButton.isEnabled = false
            currentKey = nil
        }
    }
}
