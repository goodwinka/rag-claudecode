---
source: Qt Framework Reference
language: cpp
category: qt
---

# Qt — Полный справочник

## Основы: QObject, сигналы и слоты

```cpp
#include <QObject>

class Counter : public QObject {
    Q_OBJECT  // ОБЯЗАТЕЛЬНО для сигналов/слотов
    Q_PROPERTY(int value READ value WRITE setValue NOTIFY valueChanged)

public:
    explicit Counter(QObject *parent = nullptr) : QObject(parent), m_value(0) {}
    int value() const { return m_value; }

public slots:
    void setValue(int val) {
        if (m_value != val) {
            m_value = val;
            emit valueChanged(m_value);
        }
    }
    void increment() { setValue(m_value + 1); }

signals:
    void valueChanged(int newValue);

private:
    int m_value;
};

// Соединение (новый синтаксис — type-safe)
auto conn = QObject::connect(sender, &Sender::signal, receiver, &Receiver::slot);
QObject::connect(btn, &QPushButton::clicked, this, &MyWidget::onClicked);

// Lambda
QObject::connect(btn, &QPushButton::clicked, [this]() {
    qDebug() << "Clicked!";
});

// Отключение
QObject::disconnect(conn);

// Qt::ConnectionType
Qt::AutoConnection     // авто (по потоку)
Qt::DirectConnection   // синхронный вызов (тот же поток)
Qt::QueuedConnection   // через event loop (между потоками)
Qt::UniqueConnection   // не дублировать соединения

// ВАЖНО: QObject нельзя копировать!
// Родительский объект удаляет дочерние автоматически (дерево объектов)
```

## Виджеты (Qt Widgets)

```cpp
#include <QApplication>
#include <QMainWindow>
#include <QWidget>
#include <QPushButton>
#include <QLabel>
#include <QLineEdit>
#include <QTextEdit>
#include <QComboBox>
#include <QCheckBox>
#include <QRadioButton>
#include <QSpinBox>
#include <QSlider>
#include <QProgressBar>
#include <QTableWidget>
#include <QTreeWidget>
#include <QListWidget>
#include <QTabWidget>
#include <QGroupBox>
#include <QMenuBar>
#include <QToolBar>
#include <QStatusBar>
#include <QFileDialog>
#include <QMessageBox>

// Главное окно
class MainWindow : public QMainWindow {
    Q_OBJECT
public:
    MainWindow(QWidget *parent = nullptr) : QMainWindow(parent) {
        setWindowTitle("My App");
        resize(800, 600);

        // Центральный виджет
        auto *central = new QWidget(this);
        setCentralWidget(central);

        // Меню
        auto *fileMenu = menuBar()->addMenu("&File");
        auto *openAct = fileMenu->addAction("&Open", QKeySequence::Open);
        connect(openAct, &QAction::triggered, this, &MainWindow::openFile);
        fileMenu->addSeparator();
        fileMenu->addAction("&Quit", QKeySequence::Quit, qApp, &QApplication::quit);

        // Тулбар
        auto *toolbar = addToolBar("Main");
        toolbar->addAction(openAct);

        // Статусбар
        statusBar()->showMessage("Ready");
    }

private slots:
    void openFile() {
        QString file = QFileDialog::getOpenFileName(
            this, "Open File", QDir::homePath(),
            "Text Files (*.txt);;All Files (*)"
        );
        if (!file.isEmpty()) {
            // обработка
        }
    }
};

// Диалоги
QMessageBox::information(this, "Title", "Message");
QMessageBox::warning(this, "Warning", "Something wrong");
auto btn = QMessageBox::question(this, "Confirm", "Delete?",
    QMessageBox::Yes | QMessageBox::No, QMessageBox::No);
if (btn == QMessageBox::Yes) { /* delete */ }

QString dir = QFileDialog::getExistingDirectory(this, "Select Dir");
QString file = QFileDialog::getSaveFileName(this, "Save", "", "*.txt");
```

## Layouts — управление расположением

```cpp
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QGridLayout>
#include <QFormLayout>
#include <QSplitter>
#include <QStackedWidget>

// Вертикальный
auto *vbox = new QVBoxLayout(widget);
vbox->addWidget(label);
vbox->addWidget(button);
vbox->addStretch();  // расширяемый пробел
vbox->setSpacing(10);
vbox->setContentsMargins(10, 10, 10, 10);

// Горизонтальный
auto *hbox = new QHBoxLayout;
hbox->addWidget(btn1);
hbox->addSpacing(20);
hbox->addWidget(btn2, 1);  // stretch factor = 1

// Сетка
auto *grid = new QGridLayout;
grid->addWidget(label,    0, 0);           // row, col
grid->addWidget(lineEdit, 0, 1);
grid->addWidget(textEdit, 1, 0, 1, 2);    // row, col, rowSpan, colSpan
grid->setColumnStretch(1, 1);

// Форма (label + widget)
auto *form = new QFormLayout;
form->addRow("Name:", nameEdit);
form->addRow("Email:", emailEdit);
form->addRow("", submitBtn);

// Вложенные layout
auto *main = new QVBoxLayout(widget);
auto *top = new QHBoxLayout;
top->addWidget(searchEdit);
top->addWidget(searchBtn);
main->addLayout(top);
main->addWidget(resultList);

// QSplitter — изменяемый размер
auto *splitter = new QSplitter(Qt::Horizontal);
splitter->addWidget(leftPanel);
splitter->addWidget(rightPanel);
splitter->setSizes({200, 600});
```

## Model/View архитектура

```cpp
#include <QAbstractTableModel>
#include <QTableView>
#include <QSortFilterProxyModel>

class PersonModel : public QAbstractTableModel {
    Q_OBJECT
    struct Person { QString name; int age; };
    QVector<Person> m_data;

public:
    int rowCount(const QModelIndex &parent = {}) const override {
        return m_data.size();
    }
    int columnCount(const QModelIndex &parent = {}) const override {
        return 2;
    }
    QVariant data(const QModelIndex &idx, int role = Qt::DisplayRole) const override {
        if (!idx.isValid() || role != Qt::DisplayRole) return {};
        const auto &p = m_data[idx.row()];
        switch (idx.column()) {
            case 0: return p.name;
            case 1: return p.age;
        }
        return {};
    }
    QVariant headerData(int section, Qt::Orientation o, int role) const override {
        if (role != Qt::DisplayRole || o != Qt::Horizontal) return {};
        return section == 0 ? "Name" : "Age";
    }
    // Для редактирования:
    Qt::ItemFlags flags(const QModelIndex &idx) const override {
        return QAbstractTableModel::flags(idx) | Qt::ItemIsEditable;
    }
    bool setData(const QModelIndex &idx, const QVariant &value, int role) override {
        if (role != Qt::EditRole) return false;
        auto &p = m_data[idx.row()];
        if (idx.column() == 0) p.name = value.toString();
        else p.age = value.toInt();
        emit dataChanged(idx, idx);
        return true;
    }
    // Добавление строк
    void addPerson(const QString &name, int age) {
        beginInsertRows({}, m_data.size(), m_data.size());
        m_data.append({name, age});
        endInsertRows();
    }
};

// Использование
auto *model = new PersonModel(this);
auto *proxy = new QSortFilterProxyModel(this);
proxy->setSourceModel(model);
proxy->setFilterKeyColumn(0);
proxy->setFilterCaseSensitivity(Qt::CaseInsensitive);

auto *view = new QTableView;
view->setModel(proxy);
view->setSortingEnabled(true);

// Фильтрация
connect(searchEdit, &QLineEdit::textChanged, proxy, &QSortFilterProxyModel::setFilterFixedString);
```

## Файловая система (Qt)

```cpp
#include <QFile>
#include <QDir>
#include <QFileInfo>
#include <QTextStream>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>

// Чтение текстового файла
QFile file("data.txt");
if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
    QTextStream in(&file);
    in.setEncoding(QStringConverter::Utf8);
    QString content = in.readAll();
    // или построчно:
    while (!in.atEnd()) {
        QString line = in.readLine();
    }
}

// Запись
QFile out("output.txt");
if (out.open(QIODevice::WriteOnly | QIODevice::Text)) {
    QTextStream stream(&out);
    stream << "Hello " << 42 << "\n";
}

// JSON
QJsonObject obj;
obj["name"] = "Test";
obj["value"] = 42;
QJsonDocument doc(obj);
QFile::open(QIODevice::WriteOnly);
file.write(doc.toJson());

// Чтение JSON
QFile jf("data.json");
jf.open(QIODevice::ReadOnly);
QJsonDocument jdoc = QJsonDocument::fromJson(jf.readAll());
QJsonObject root = jdoc.object();
QString name = root["name"].toString();

// QSettings — настройки приложения
QSettings settings("MyCompany", "MyApp");
settings.setValue("window/size", size());
QSize savedSize = settings.value("window/size", QSize(800, 600)).toSize();

// QDir
QDir dir("/path");
QStringList files = dir.entryList({"*.cpp", "*.h"}, QDir::Files);
dir.mkpath("subdir/nested");
bool exists = QFileInfo::exists("file.txt");
qint64 fileSize = QFileInfo("file.txt").size();
```

## Сеть (Qt Network)

```cpp
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QTcpServer>
#include <QTcpSocket>

// HTTP запросы
auto *manager = new QNetworkAccessManager(this);

// GET
QNetworkRequest req(QUrl("https://api.example.com/data"));
req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
QNetworkReply *reply = manager->get(req);
connect(reply, &QNetworkReply::finished, [reply]() {
    if (reply->error() == QNetworkReply::NoError) {
        QByteArray data = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(data);
    } else {
        qWarning() << "Error:" << reply->errorString();
    }
    reply->deleteLater();
});

// POST
QJsonObject body;
body["key"] = "value";
QNetworkReply *reply = manager->post(req, QJsonDocument(body).toJson());

// TCP сервер
auto *server = new QTcpServer(this);
connect(server, &QTcpServer::newConnection, [this, server]() {
    QTcpSocket *socket = server->nextPendingConnection();
    connect(socket, &QTcpSocket::readyRead, [socket]() {
        QByteArray data = socket->readAll();
        socket->write("Response\n");
    });
    connect(socket, &QTcpSocket::disconnected, socket, &QTcpSocket::deleteLater);
});
server->listen(QHostAddress::Any, 8080);
```

## Многопоточность в Qt

```cpp
#include <QThread>
#include <QMutex>
#include <QRunnable>
#include <QThreadPool>
#include <QtConcurrent>

// Способ 1: moveToThread (РЕКОМЕНДУЕМЫЙ)
class Worker : public QObject {
    Q_OBJECT
public slots:
    void doWork(const QString &param) {
        // тяжёлая работа (в отдельном потоке)
        emit resultReady(result);
    }
signals:
    void resultReady(const QString &result);
};

auto *thread = new QThread;
auto *worker = new Worker;
worker->moveToThread(thread);
connect(thread, &QThread::started, worker, [worker]{ worker->doWork("param"); });
connect(worker, &Worker::resultReady, this, &MyWidget::handleResult);
connect(worker, &Worker::resultReady, thread, &QThread::quit);
connect(thread, &QThread::finished, worker, &QObject::deleteLater);
connect(thread, &QThread::finished, thread, &QObject::deleteLater);
thread->start();

// Способ 2: QtConcurrent (простые задачи)
QFuture<int> future = QtConcurrent::run([]() -> int {
    // тяжёлое вычисление
    return 42;
});

QFutureWatcher<int> *watcher = new QFutureWatcher<int>(this);
connect(watcher, &QFutureWatcher<int>::finished, [watcher]() {
    int result = watcher->result();
    watcher->deleteLater();
});
watcher->setFuture(future);

// Способ 3: QThreadPool + QRunnable
class Task : public QRunnable {
    void run() override { /* работа */ }
};
QThreadPool::globalInstance()->start(new Task);

// ВАЖНО: GUI только из главного потока!
// Для обновления GUI из потока: сигналы/слоты с QueuedConnection
// или QMetaObject::invokeMethod(obj, "slot", Qt::QueuedConnection);
```

## QML основы

```qml
// main.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ApplicationWindow {
    visible: true
    width: 800; height: 600
    title: "QML App"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20

        TextField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: "Enter name"
        }

        Button {
            text: "Submit"
            onClicked: {
                console.log("Name:", nameField.text)
                backend.processName(nameField.text)
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: myModel
            delegate: ItemDelegate {
                text: model.display
                width: parent.width
            }
        }
    }
}
```

```cpp
// Регистрация C++ объекта в QML
#include <QQmlApplicationEngine>
#include <QQmlContext>

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;

    Backend backend;
    engine.rootContext()->setContextProperty("backend", &backend);

    engine.load(QUrl("qrc:/main.qml"));
    return app.exec();
}
```
