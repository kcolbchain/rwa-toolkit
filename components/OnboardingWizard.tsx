import { useState } from 'react';
import { WalletConnector } from './WalletConnector';
import { GeographySelector } from './GeographySelector';
import { AccreditationCheck } from './AccreditationCheck';
import { KYCForm } from './KYCForm';

type Step = 'wallet' | 'geography' | 'accreditation' | 'kyc' | 'complete';

interface KYCData {
  fullName: string;
  dateOfBirth: string;
  nationality: string;
  documentType: string;
  documentNumber: string;
  email: string;
}

export function OnboardingWizard() {
  const [step, setStep] = useState<Step>('wallet');
  const [walletAddress, setWalletAddress] = useState<string>('');
  const [jurisdiction, setJurisdiction] = useState<string>('');
  const [accreditation, setAccreditation] = useState<string>('');
  const [kycData, setKycData] = useState<KYCData | null>(null);

  async function handleKYCSubmit(data: KYCData) {
    setKycData(data);
    try {
      const res = await fetch('/api/onboarding/kyc', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ wallet: walletAddress, ...data }),
      });
      if (!res.ok) throw new Error('KYC submission failed');
      setStep('complete');
    } catch (e: any) {
      alert('KYC submission failed: ' + e.message);
    }
  }

  function reset() {
    setStep('wallet');
    setWalletAddress('');
    setJurisdiction('');
    setAccreditation('');
    setKycData(null);
  }

  return (
    <div className="onboarding-wizard">
      <h1>RWA Investor Onboarding</h1>

      <div className="progress">
        Step: {step.replace('-', ' ').replace(/\b\w/g, c => c.toUpperCase())}
      </div>

      {step === 'wallet' && (
        <>
          <WalletConnector onConnected={(addr) => { setWalletAddress(addr); setStep('geography'); }} />
        </>
      )}

      {step === 'geography' && (
        <GeographySelector onSelect={(geo) => { setJurisdiction(geo); setStep('accreditation'); }} />
      )}

      {step === 'accreditation' && (
        <AccreditationCheck
          jurisdiction={jurisdiction}
          onSelect={(type) => { setAccreditation(type); setStep('kyc'); }}
        />
      )}

      {step === 'kyc' && (
        <KYCForm onSubmit={handleKYCSubmit} walletAddress={walletAddress} />
      )}

      {step === 'complete' && (
        <div className="complete">
          <h2>Onboarding Complete!</h2>
          <p>Wallet: {walletAddress}</p>
          <p>Jurisdiction: {jurisdiction}</p>
          <p>Accreditation: {accreditation}</p>
          {kycData && <p>KYC submitted for: {kycData.fullName}</p>}
          <button onClick={reset}>Start Over</button>
        </div>
      )}
    </div>
  );
}
