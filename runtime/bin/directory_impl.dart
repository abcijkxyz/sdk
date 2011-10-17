// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.


class DirectoryException {
  const DirectoryException(String this.message);
  final String message;
}


class _DirectoryListingIsolate extends Isolate {

  _DirectoryListingIsolate() : super.heavy();

  void main() {
    port.receive((message, replyTo) {
       _list(message['dir'],
             message['id'],
             message['recursive'],
             message['dirHandler'],
             message['fileHandler'],
             message['doneHandler'],
             message['dirErrorHandler']);
    });
  }

  void _list(String dir,
             int id,
             bool recursive,
             SendPort dirHandler,
             SendPort fileHandler,
             SendPort doneHandler,
             SendPort dirErrorHandler) native "Directory_List";
}


class _Directory implements Directory {

  _Directory.open(String this._dir) {
    _id = 0;
    _closed = false;
    _listing = false;
    if (!_open(_dir)) {
      _closed = true;
      throw new DirectoryException("Error: could not open directory");
    }
  }

  bool close() {
    if (_closed) {
      throw new DirectoryException("Error: directory closed");
    }
    if (_close(_id)) {
      _closePort(_dirHandler);
      _closePort(_fileHandler);
      _closePort(_doneHandler);
      _closePort(_dirErrorHandler);
      _closed = true;
      bool was_listing = _listing;
      _listing = false;
      if (was_listing && _doneHandler !== null) {
        _doneHandler(false);
      }
      return true;
    }
    return false;
  }

  void list([bool recursive = false]) {
    if (_closed) {
      throw new DirectoryException("Error: directory closed");
    }
    if (_listing) {
      throw new DirectoryException("Error: listing already in progress");
    }
    _listing = true;
    new _DirectoryListingIsolate().spawn().then((port) {
      // TODO(ager): Do not explicitly transform to send ports when
      // that is done automatically.
      port.send({ 'dir': _dir,
                  'id': _id,
                  'recursive': recursive,
                  'dirHandler': _dirHandler.toSendPort(),
                  'fileHandler': _fileHandler.toSendPort(),
                  'doneHandler': _doneHandler.toSendPort(),
                  'dirErrorHandler': _dirErrorHandler.toSendPort() });
    });
  }

  // TODO(ager): Implement setting of the handlers as in the process library.
  void setDirHandler(void dirHandler(String dir)) {
    if (_closed) {
      throw new DirectoryException("Error: directory closed");
    }
    if (_dirHandler === null) {
      _dirHandler = new ReceivePort();
    }
    _dirHandler.receive((String dir, ignored) => dirHandler(dir));
  }

  void setFileHandler(void fileHandler(String file)) {
    if (_closed) {
      throw new DirectoryException("Error: directory closed");
    }
    if (_fileHandler === null) {
      _fileHandler = new ReceivePort();
    }
    _fileHandler.receive((String file, ignored) => fileHandler(file));
  }

  void setDoneHandler(void doneHandler(bool completed)) {
    if (_closed) {
      throw new DirectoryException("Error: directory closed");
    }
    if (_doneHandler === null) {
      _doneHandler = new ReceivePort();
    }
    _doneHandler.receive((bool completed, ignored) {
      _listing = false;
      doneHandler(completed);
    });
  }

  void setDirErrorHandler(void errorHandler(String dir)) {
    if (_closed) {
      throw new DirectoryException("Error: directory closed");
    }
    if (_dirErrorHandler === null) {
      _dirErrorHandler = new ReceivePort();
    }
    _dirErrorHandler.receive((String dir, ignored) {
      errorHandler(dir, completed);
    });
  }

  // Utility methods.
  void _closePort(ReceivePort port) {
    if (port !== null) {
      port.close();
    }
  }

  // Native code binding.
  bool _open(String dir) native "Directory_Open";
  bool _close(int id) native "Directory_Close";

  ReceivePort _dirHandler;
  ReceivePort _fileHandler;
  ReceivePort _doneHandler;
  ReceivePort _dirErrorHandler;

  String _dir;
  int _id;
  bool _closed;
  bool _listing;
}