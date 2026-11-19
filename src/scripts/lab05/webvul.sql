-- phpMyAdmin SQL Dump
-- version 4.5.1
-- http://www.phpmyadmin.net
--
-- Host: 127.0.0.1
-- Generation Time: Dec 23, 2020 at 02:54 AM
-- Server version: 10.1.16-MariaDB
-- PHP Version: 5.5.38

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `webvul2`
--

-- --------------------------------------------------------

--
-- Table structure for table `tbl_blog`
--

CREATE TABLE `tbl_blog` (
  `id` int(10) UNSIGNED NOT NULL,
  `author` varchar(256) NOT NULL,
  `post` varchar(128) NOT NULL,
  `address` varchar(32) NOT NULL,
  `time` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `tbl_blog`
--

INSERT INTO `tbl_blog` (`id`, `author`, `post`, `address`, `time`) VALUES
(106, 'Tung', 'HelloWorld', '127.0.0.1', '2020-12-15 14:51:32');

-- --------------------------------------------------------

--
-- Table structure for table `tbl_history`
--

CREATE TABLE `tbl_history` (
  `id` int(11) NOT NULL,
  `studentid` char(8) NOT NULL,
  `address` varchar(50) DEFAULT NULL,
  `browser` varchar(500) DEFAULT NULL,
  `date` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `tbl_history`
--

INSERT INTO `tbl_history` (`id`, `studentid`, `address`, `browser`, `date`) VALUES
(1, '', '127.0.0.1', 'http://xss.attt.vn/xss3.html', '2020-12-18 11:03:41'),
(2, '', '127.0.0.1', NULL, '2020-12-18 11:51:55'),
(3, '', '127.0.0.1', 'http://xss.attt.vn/', '2020-12-21 10:36:24'),
(4, '', '127.0.0.1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.198 Safari/537.36 OPR/72.0.3815.400', '2020-12-21 10:36:27'),
(5, '', '127.0.0.1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36', '2020-12-21 10:36:44'),
(6, '', '127.0.0.1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:84.0) Gecko/20100101 Firefox/84.0', '2020-12-21 10:36:52'),
(7, '', '127.0.0.1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36', '2020-12-21 20:33:38');

-- --------------------------------------------------------

--
-- Table structure for table `tbl_product`
--

CREATE TABLE `tbl_product` (
  `id` int(10) UNSIGNED NOT NULL,
  `vendor` varchar(256) NOT NULL,
  `model` varchar(256) NOT NULL,
  `price` int(10) UNSIGNED NOT NULL,
  `category` varchar(64) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `tbl_product`
--

INSERT INTO `tbl_product` (`id`, `vendor`, `model`, `price`, `category`) VALUES
(1, 'HP', 'Probook 450 G3', 500, 'laptop'),
(3, 'Dell', 'XPS 13', 1000, 'laptop'),
(4, 'Dell', 'Precision M7510', 1500, 'laptop'),
(5, 'Apple', 'Macbook Retina 2017', 2000, 'laptop'),
(6, 'Secret', 'Secret 2017', 10000000, 'secret'),
(7, 'Logitech', 'M150', 20, 'mouse'),
(8, 'Genius', 'G400', 70, 'keyboard');

-- --------------------------------------------------------

--
-- Table structure for table `tbl_users`
--

CREATE TABLE `tbl_users` (
  `id` int(10) UNSIGNED NOT NULL,
  `userid` varchar(64) NOT NULL,
  `passwd` varchar(32) NOT NULL,
  `fname` varchar(50) NOT NULL,
  `lname` varchar(50) NOT NULL,
  `gender` varchar(1) NOT NULL,
  `dtob` date NOT NULL,
  `country` varchar(32) NOT NULL,
  `emailid` varchar(64) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `tbl_users`
--

INSERT INTO `tbl_users` (`id`, `userid`, `passwd`, `fname`, `lname`, `gender`, `dtob`, `country`, `emailid`) VALUES
(1, 'admin', '81a58e89df1f34c5487568e17327a219', 'Admin', 'Admin', 'M', '2017-09-06', 'Vietnam', 'admin@webvul.attt.vn'),
(2, 'lovelace', 'af1bf2dd07e1753f7012d653101826f0', 'Ada', 'Lovelace', 'F', '1815-12-10', 'England', 'ada@webvul.cysec.vn'),
(3, 'mcnulty', 'd2a5f66879748cbe548dfd77f939e818', 'Kay', 'McNulty', 'F', '1921-02-12', 'US', 'mcnulty@webvul.cysec.vn'),
(4, 'neumann', 'ba3b05bd11ea46ae6bb9c8f51eb2bf93', 'John von', 'Neumann', 'M', '1903-12-28', 'Hungary', 'neumann@webvul.cysec.vn'),
(5, 'ritchie', 'cfd21ceef60a9a5858a015296afca825', 'Dennis', 'Ritchie', 'M', '1941-09-09', 'US', 'ritchie@webvul.cysec.vn'),
(6, 'secret', '5d7845ac6ee7cfffafc5fe5f35cf666d', 'Big', 'Secret', 'F', '2017-10-11', 'Vietnam', 'secret@webvul.cysec.vn'),
(7, 'turing', '9f66256e2ad6440dac643693d7d657eb', 'Alan', 'Turing', 'M', '1912-06-23', 'England', 'turing@webvul.cysec.vn');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `tbl_blog`
--
ALTER TABLE `tbl_blog`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `tbl_history`
--
ALTER TABLE `tbl_history`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `tbl_product`
--
ALTER TABLE `tbl_product`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `tbl_users`
--
ALTER TABLE `tbl_users`
  ADD PRIMARY KEY (`id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `tbl_blog`
--
ALTER TABLE `tbl_blog`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=107;
--
-- AUTO_INCREMENT for table `tbl_history`
--
ALTER TABLE `tbl_history`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;
--
-- AUTO_INCREMENT for table `tbl_product`
--
ALTER TABLE `tbl_product`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
