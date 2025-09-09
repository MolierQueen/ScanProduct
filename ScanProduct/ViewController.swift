import UIKit
import AVFoundation

class ViewController: UIViewController {

    let scanCodeButton = UIButton(type: .system)
    let viewAllButton = UIButton(type: .system)
    
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
        scanCodeButton.setTitle("扫描条形码", for: .normal)
        scanCodeButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold) // 字体加大
        scanCodeButton.addTarget(self, action: #selector(scanCode), for: .touchUpInside)
        scanCodeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scanCodeButton)

        viewAllButton.setTitle("查看所有物品", for: .normal)
        viewAllButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold) // 字体加大
        viewAllButton.addTarget(self, action: #selector(showAllItems), for: .touchUpInside)
        viewAllButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(viewAllButton)
        
        NSLayoutConstraint.activate([
            scanCodeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanCodeButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            
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
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            
            if let value = self.dataDict[code] {
                // 已存在 → 弹 Alert 展示 title 和 des
                let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
                
                // 设置 title 和 message 的属性
                let titleAttr = NSAttributedString(string: value["title"] ?? "", attributes: [
                    .font: UIFont.systemFont(ofSize: 20, weight: .bold)
                ])
                let messageAttr = NSAttributedString(string: value["des"] ?? "", attributes: [
                    .font: UIFont.systemFont(ofSize: 18)
                ])
                
                alert.setValue(titleAttr, forKey: "attributedTitle")
                alert.setValue(messageAttr, forKey: "attributedMessage")
                
                alert.addAction(UIAlertAction(title: "知道了", style: .default, handler: nil))
                self.present(alert, animated: true)
            } else {
                // 不存在 → 弹 Alert 录入信息
                let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
                
                let titleAttr = NSAttributedString(string: "请录入信息", attributes: [
                    .font: UIFont.systemFont(ofSize: 20, weight: .bold)
                ])
                alert.setValue(titleAttr, forKey: "attributedTitle")
                
                alert.addTextField { $0.placeholder = "title" }
                alert.addTextField { $0.placeholder = "des" }
                
                alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { _ in
                    guard let title = alert.textFields?[0].text, !title.isEmpty,
                          let des = alert.textFields?[1].text, !des.isEmpty else { return }
                    self.dataDict[code] = ["title": title, "des": des]
                    self.saveData()
                }))
                self.present(alert, animated: true)
            }
        }
    }
}

// MARK: - AllItems Delegate
extension ViewController: AllItemsViewControllerDelegate {
    func updateDataDict(_ dataDict: [String : [String : String]]) {
        self.dataDict = dataDict
        saveData()
    }
    
    func deleteItem(forKey key: String) {
        dataDict.removeValue(forKey: key)
        saveData()
    }
}
