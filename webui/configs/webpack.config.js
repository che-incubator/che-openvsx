// @ts-check

/* eslint-disable no-undef */
const webpack = require('webpack');
const path = require('path');
const BundleAnalyzerPlugin = require('webpack-bundle-analyzer').BundleAnalyzerPlugin;

/** @type {webpack.Configuration} */
const config = {
    entry: [
        './lib/default/default-app.js'
    ],
    output: {
        filename: 'bundle.js',
        path: path.resolve(__dirname, '../static'),
        publicPath: '/'
    },
    devtool: 'source-map',

    resolve: {
        extensions: ['.js', '.jsx']
    },
    module: {
        rules: [
            {
                test: /\.jsx?$/,
                use: ['source-map-loader'],
                enforce: 'pre'
            },
            {
                test: /\.css$/,
                exclude: /\.useable\.css$/,
                use: ['style-loader', 'css-loader']
            }
        ]
    },
    node: false,

    plugins: [
        new webpack.ProgressPlugin({}),
        new BundleAnalyzerPlugin({
            analyzerMode: 'static',
            reportFilename: 'webpack-report.html'
        })
    ]
};
module.exports = config;
