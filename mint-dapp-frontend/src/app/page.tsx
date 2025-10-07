"use client";

import React, { useState } from "react";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useAccount, useWriteContract } from "wagmi";
import { abi as ABI } from "./abi/JobsNFTFull";

const CONTRACT_ADDRESS = "0x2A8294462F7424a71c786BaBa617B2e644a31393";
export default function Home() {
  const { address, isConnected } = useAccount();

  const { writeContract, isPending, isSuccess } = useWriteContract();

  const [imageUrl, setImageUrl] = useState("");


  const handleMint = async () => {
    if (!address) return;
    writeContract({
      abi: ABI,
      address: "0x2A8294462F7424a71c786BaBa617B2e644a31393",
      functionName: "mint",
      args: [address, "https://chocolate-official-crocodile-904.mypinata.cloud/ipfs/bafkreibvuthyde37cxj5clxzxfggr2iiffxb2da6p7tj65tkaxqgm35f2q"],
    });
    setImageUrl("https://chocolate-official-crocodile-904.mypinata.cloud/ipfs/bafybeiboxucsdfbeqmtfvzyii45i3rdmqi6eznmj4kzaraxi4adtexsalu"); // tvoj URL
  };

  return (
    <main
      style={{
        backgroundColor: "#000",
        color: "#fff",
        minHeight: "100vh",
        padding: "2rem",
      }}
    >
      <h1>JobsNFT Mint dApp</h1>
      <ConnectButton />
      {isConnected && (
        <button
          onClick={handleMint}
          disabled={isPending}
          style={{
            marginTop: "5px",
            padding: "12px 24px",
            fontSize: "16px",
            backgroundColor: "#333",
            color: "#fff",
            border: "none",
            cursor: "pointer",
          }}
        >
          {isPending ? "Minting..." : "Mint NFT"}
        </button>
      )}
  {imageUrl && (
      <div style={{ marginTop: '30px' }}>
        <p>✅ Tvoj NFT:</p>
        <img
          src={imageUrl}
          alt="Minted NFT"
          style={{ maxWidth: '90vw', borderRadius: '10px', marginTop: '10px' }}
        />
      </div>
    )}
    </main>
  );
}
