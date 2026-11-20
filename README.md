# Overview

This repository contains several RAP (RESTful Application Programming Model) Business Objects (BOs) that model, for training and demonstration purposes, the processes and business logic of a bookstore inventory management application. I use this made-up use case to showcase some of RAP's new and standard features, together with best practices. By doing this, I aim to achieve the following goals:
1. Help other colleagues interested in learning how to design and implement BOs using RAP's framework, and expose these BOs via Fiori Element OData V4 applications or APIs.
2. Receive feedback, especially regarding points to improve or new features to try out.
2. Showcase some of my skills for those that don't know me and might like to have me on their team. 

application is built with SAP's RESTful Application Programming Model (RAP). It showcases RAP best practices and newer features such as optimized draft activation, action prechecks and defaults, and UI side effects. The business objects are exposed through OData V4 UI services as SAP Fiori elements applications. You can try both apps directly from the service binding preview in ABAP Development Tools (ADT).

## Business objects

- **BookMasterData** is the shared catalog of titles, authors, and languages. It supports draft-enabled creation, editing, and deletion. RAP assigns each catalog entry its `BookID` and checks for duplicate title, author, and language combinations on save.
- **Bookstore** is the draft-enabled root for each store. Stores can be created, edited, and deleted. A name and city are required at creation. Each store owns its inventory through the `_Books` composition, and the `ReStockBook` action lets users replenish stock with default action parameters.
- **Book** is an inventory entry within a bookstore, not a standalone root. Each entry references a **BookMasterData** record by `BookID` and tracks the number of copies in stock. Entries are created through their parent bookstore and can be updated or deleted. RAP checks that the book exists in the catalog and is not already in that store's inventory. The `TransferBook` action moves copies to another store and refreshes the displayed stock count. The backend also defines `TransferBookToBookstores` for multiple destinations; this action is not exposed in the Fiori elements UI.

## BO Behavior

## Installation

**Prerequisites:** An SAP BTP trial account, a subscription to SAP BTP, ABAP environment, and an ADT connection to that environment.

1. In ADT, create a new ABAP package, for example `ZDGD_BOOKSTORE_001`. **If the target package already exists, stop. Do not import into it.**
2. Clone `https://github.com/dgarciaduque/zdgd_bookstore_001` with abapGit. When prompted, select the package you just created.
3. Activate all imported objects. If mass activation fails, activate the required dependencies individually, then retry mass activation.
4. Run class `ZDGD_POPULATE_BOOK_MASTER_DATA` to load the sample catalog.
5. Run class `ZDGD_POPULATE_BOOKSTORE` to load the sample stores and their inventory.
6. In ADT, open service binding `ZDGD_BOOKMASTERDATA_UI` and choose **Publish**. Repeat for `ZDGD_BOOKSTORE_UI`.
7. In each service binding, select the entity set below and choose **Preview**:

   | Application | Service binding | Entity set |
   | --- | --- | --- |
   | Book Master Data | `ZDGD_BOOKMASTERDATA_UI` | `Books` |
   | Bookstore | `ZDGD_BOOKSTORE_UI` | `Bookstores` |
